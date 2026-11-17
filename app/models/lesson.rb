class Lesson < ApplicationRecord
  TRIAL_MINUTES = 30
  MIN_NOTICE = 12.hours
  CANCEL_NOTICE = 6.hours
  REMINDER_WINDOW = 1.hour
  BOOKING_WINDOW_DAYS = 14
  JOIN_OPENS = 5.minutes
  JOIN_CLOSES = 10.minutes

  belongs_to :teacher_profile
  belongs_to :student
  belongs_to :booked_by, class_name: "User"
  belongs_to :cancelled_by, class_name: "User", optional: true

  enum :status, { scheduled: "scheduled", cancelled: "cancelled", completed: "completed" }, prefix: true

  scope :upcoming, -> { status_scheduled.where("ends_at > ?", Time.current) }
  scope :history, -> { where("status <> 'scheduled' OR ends_at <= ?", Time.current) }
  # Lessons starting within the next hour that nobody has been reminded about yet.
  scope :needing_reminder, lambda {
    status_scheduled.where(reminder_sent_at: nil)
                    .where(starts_at: Time.current..(Time.current + REMINDER_WINDOW))
  }

  before_validation :set_end_time, on: :create

  validates :starts_at, presence: true
  validate :ends_after_start
  validate :student_belongs_to_booker
  validate :teacher_must_be_approved, on: :create
  validate :time_must_be_open, on: :create
  validate :student_must_be_free, on: :create
  validate :one_trial_per_teacher, on: :create, if: :trial?

  def duration_minutes
    ((ends_at - starts_at) / 60).round
  end

  def display_status
    status_scheduled? && ends_at <= Time.current ? "past" : status
  end

  # The parent who booked it or the teacher can cancel, up to 6 hours before the start.
  def cancellable_by?(user)
    status_scheduled? &&
      starts_at > Time.current + CANCEL_NOTICE &&
      [booked_by_id, teacher_profile.user_id].include?(user.id)
  end

  def cancel!(user)
    update!(status: "cancelled", cancelled_by: user, cancelled_at: Time.current)
  end

  def participant?(user)
    user.present? && [booked_by_id, teacher_profile.user_id].include?(user.id)
  end

  # The video room can be entered from 5 minutes before the start until 10 minutes after the end.
  def join_open?(now = Time.current)
    status_scheduled? && now >= starts_at - JOIN_OPENS && now <= ends_at + JOIN_CLOSES
  end

  # The private room is created the first time someone joins (never for cancelled lessons).
  # The row is locked, so two people joining at the same moment cannot create two rooms.
  def ensure_video_room!(client: nil)
    return if video_room_url.present?

    client ||= DailyClient.new
    with_lock do
      next if video_room_url.present?

      update!(video_room_name: "lesson-#{id}-#{SecureRandom.hex(8)}") if video_room_name.blank?
      room = client.create_room(name: video_room_name, starts_at: starts_at, ends_at: ends_at)
      url = room["url"].to_s
      raise DailyClient::Error, "Unexpected room address" unless url.start_with?("https://")

      update!(video_room_url: url)
    end
  end

  # The address to put in the page for this person: the room plus a personal token.
  def join_url_for(user, client: nil)
    raise ArgumentError, "not a participant" unless participant?(user)

    client ||= DailyClient.new
    ensure_video_room!(client: client)

    teacher = user.id == teacher_profile.user_id
    token = client.create_token(
      room_name: video_room_name,
      user_name: join_display_name(user, teacher),
      owner: teacher,
      starts_at: starts_at,
      ends_at: ends_at,
      lang: user.locale
    )
    "#{video_room_url}?t=#{CGI.escape(token)}"
  end

  private

  # First names only. Teachers appear as "Firstname L." like on their public profile.
  def join_display_name(user, teacher)
    return user.first_name.to_s unless teacher

    initial = user.last_name.to_s.strip[0]
    [user.first_name, initial && "#{initial}."].compact_blank.join(" ")
  end

  def set_end_time
    self.ends_at = starts_at + TRIAL_MINUTES.minutes if starts_at && ends_at.nil?
  end

  def ends_after_start
    return unless starts_at && ends_at

    errors.add(:ends_at, :invalid) unless ends_at > starts_at
  end

  def student_belongs_to_booker
    return unless student && booked_by

    errors.add(:student, :invalid) unless student.parent_id == booked_by_id && booked_by.role_parent?
  end

  def teacher_must_be_approved
    errors.add(:teacher_profile, :invalid) unless teacher_profile&.status_approved?
  end

  def time_must_be_open
    return unless starts_at && teacher_profile

    open_times = teacher_profile.bookable_starts(minutes: TRIAL_MINUTES, days: BOOKING_WINDOW_DAYS)
    errors.add(:starts_at, :not_available) unless open_times.include?(starts_at)
  end

  def student_must_be_free
    return unless starts_at && ends_at && student_id

    busy = Lesson.status_scheduled.where(student_id: student_id)
                 .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
    errors.add(:base, :student_busy) if busy.exists?
  end

  def one_trial_per_teacher
    return unless student_id && teacher_profile_id

    already = Lesson.where(student_id: student_id, teacher_profile_id: teacher_profile_id, trial: true)
                    .where.not(status: "cancelled")
    errors.add(:base, :trial_already_booked) if already.exists?
  end
end
