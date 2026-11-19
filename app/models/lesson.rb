class Lesson < ApplicationRecord
  include LessonCompletion
  TRIAL_MINUTES = 30
  PAID_MINUTES = 60
  MIN_NOTICE = 12.hours
  CANCEL_NOTICE = 6.hours
  REMINDER_WINDOW = 1.hour
  BOOKING_WINDOW_DAYS = 14
  JOIN_OPENS = 5.minutes
  JOIN_CLOSES = 10.minutes
  # Stripe payment pages live at least 30 minutes; the time stays held a little longer than the page.
  SESSION_MINUTES = 31
  HOLD_MINUTES = 32

  belongs_to :teacher_profile
  belongs_to :student
  belongs_to :booked_by, class_name: "User"
  belongs_to :cancelled_by, class_name: "User", optional: true
  has_one :order, dependent: :restrict_with_error

  enum :status,
       { scheduled: "scheduled", cancelled: "cancelled", completed: "completed",
         pending_payment: "pending_payment", expired: "expired" },
       prefix: true

  # Times that are taken: booked lessons and lessons waiting for payment.
  scope :active, -> { where(status: %w[scheduled pending_payment]) }
  scope :upcoming, -> { status_scheduled.where("ends_at > ?", Time.current) }
  scope :history, lambda {
    where.not(status: %w[pending_payment expired]).where("status <> 'scheduled' OR ends_at <= ?", Time.current)
  }
  # Lessons starting within the next hour that nobody has been reminded about yet.
  scope :needing_reminder, lambda {
    status_scheduled.where(reminder_sent_at: nil)
                    .where(starts_at: Time.current..(Time.current + REMINDER_WINDOW))
  }

  before_validation :set_end_time, on: :create

  validates :starts_at, presence: true
  validates :price_cents, numericality: { only_integer: true, greater_than: 0 }, on: :create, unless: :trial?
  validate :ends_after_start
  validate :student_belongs_to_booker
  validate :teacher_must_be_approved, on: :create
  validate :time_must_be_open, on: :create
  validate :student_must_be_free, on: :create
  validate :one_trial_per_teacher, on: :create, if: :trial?

  # Frees every time that was held for a payment which never arrived.
  def self.release_expired_holds!
    status_pending_payment.where("hold_expires_at <= ?", Time.current).find_each do |lesson|
      lesson.with_lock do
        next unless lesson.status_pending_payment? && lesson.hold_expires_at <= Time.current

        lesson.order&.update!(status: "expired") if lesson.order&.status_pending?
        lesson.update!(status: "expired")
      end
    end
  end

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

  # A paid lesson is flagged for a full refund in the same step.
  def cancel!(user)
    transaction do
      update!(status: "cancelled", cancelled_by: user, cancelled_at: Time.current)
      order&.request_refund!
    end
  end

  def participant?(user)
    user.present? && [booked_by_id, teacher_profile.user_id].include?(user.id)
  end

  # The video room can be entered from 5 minutes before the start until 10 minutes after the end.
  def join_open?(now = Time.current)
    status_scheduled? && now >= starts_at - JOIN_OPENS && now <= ends_at + JOIN_CLOSES
  end

  # Emails are queued in the background; a mail problem must never undo or block a booking.
  def notify_participants(kind, cancelled_by: nil)
    [[booked_by, "parent"], [teacher_profile.user, "teacher"]].each do |recipient, role|
      LessonMailer.with(lesson: self, recipient: recipient, role: role, cancelled_by: cancelled_by)
                  .public_send(kind).deliver_later
    end
  rescue StandardError => e
    Rails.logger.error("Lesson email (#{kind}) could not be queued: #{e.class}: #{e.message}")
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
    return unless starts_at && ends_at && teacher_profile

    open_times = teacher_profile.bookable_starts(minutes: duration_minutes, days: BOOKING_WINDOW_DAYS)
    errors.add(:starts_at, :not_available) unless open_times.include?(starts_at)
  end

  def student_must_be_free
    return unless starts_at && ends_at && student_id

    busy = Lesson.active.where(student_id: student_id)
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
