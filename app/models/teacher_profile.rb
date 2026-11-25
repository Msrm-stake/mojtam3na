class TeacherProfile < ApplicationRecord
  include TeacherPayouts
  CURRENCIES = %w[EUR].freeze
  PHOTO_TYPES = %w[image/jpeg image/png].freeze
  PHOTO_MAX_BYTES = 1_500_000

  belongs_to :user
  belongs_to :approved_by, class_name: "User", optional: true

  has_many :teacher_languages, dependent: :destroy
  has_many :languages, through: :teacher_languages
  has_many :teacher_subjects, dependent: :destroy
  has_many :subjects, through: :teacher_subjects
  has_many :qualifications, dependent: :destroy
  has_many :availability_slots, dependent: :destroy
  has_many :lessons, dependent: :destroy

  # The live photo is shown to parents. A new photo waits in pending_photo until an admin approves it,
  # and the old live photo stays visible meanwhile. Both are stored in the private bucket.
  has_one_attached :photo
  has_one_attached :pending_photo

  # Only approved profiles appear in search.
  enum :status, { pending: "pending", approved: "approved", rejected: "rejected", suspended: "suspended" }, prefix: true
  enum :background_check_status,
       { not_started: "not_started", pending: "pending", passed: "passed", failed: "failed" },
       prefix: :background_check

  before_validation :normalize_fields

  validates :currency, inclusion: { in: CURRENCIES }
  validates :hourly_rate_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :years_experience, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :min_age, :max_age, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :gender, inclusion: { in: %w[female male] }, allow_nil: true
  validates :intro_video_url, format: { with: %r{\Ahttps?://\S+\z}i }, allow_nil: true
  validate :user_must_be_teacher
  validate :pending_photo_rules

  def hourly_rate
    hourly_rate_cents / 100.0
  end

  # The form works in euros ("12,50" or "12.50"); the database stores cents.
  def hourly_rate=(value)
    return if value.blank?

    self.hourly_rate_cents = (value.to_s.tr(",", ".").to_d * 100).round
  end

  # What is still missing before an admin may approve this profile.
  def missing_for_approval
    missing = []
    missing << :language unless teacher_languages.exists?
    missing << :subject unless teacher_subjects.exists?
    missing
  end

  # What the teacher must fill in before sending the profile for review (certificates stay optional, a price is required).
  def missing_for_submission
    missing = []
    missing << :headline if headline.blank?
    missing << :bio if bio.blank?
    missing << :language unless teacher_languages.exists?
    missing << :subject unless teacher_subjects.exists?
    missing << :price unless hourly_rate_cents.to_i.positive?
    missing << :availability unless availability_slots.exists?
    missing
  end

  # Shown as a badge on the teacher cards: at least one qualification checked by an admin.
  def verified_teacher?
    qualifications.any?(&:status_verified?)
  end

  def submitted?
    submitted_at.present?
  end

  def submit_for_review!
    update!(status: "pending", submitted_at: Time.current, rejection_reason: nil)
  end

  def approve!(admin)
    update!(status: "approved", approved_by: admin, approved_at: Time.current, rejection_reason: nil)
  end

  def reject!(reason)
    update!(status: "rejected", rejection_reason: reason, approved_by: nil, approved_at: nil)
  end

  def suspend!
    update!(status: "suspended")
  end

  # Start times (as moments in time) when a lesson of this length can be booked, soonest first.
  # Weekly availability is read in the teacher's own time zone; times already taken are removed.
  def bookable_starts(minutes: Lesson::TRIAL_MINUTES, days: Lesson::BOOKING_WINDOW_DAYS)
    zone = user.zone
    now = Time.current
    earliest = now + Lesson::MIN_NOTICE
    latest = now + days.days
    length = minutes.minutes

    busy = lessons.active
                  .where("ends_at > ? AND starts_at < ?", earliest, latest + length)
                  .pluck(:starts_at, :ends_at)
    by_weekday = availability_slots.group_by(&:weekday)

    starts = []
    (earliest.in_time_zone(zone).to_date..latest.in_time_zone(zone).to_date).each do |date|
      (by_weekday[date.wday] || []).each do |slot|
        minute = slot.start_minute
        while minute + minutes <= slot.end_minute
          start = zone.local(date.year, date.month, date.day, minute / 60, minute % 60)
          free = busy.none? { |from, to| from < start + length && to > start }
          starts << start if start >= earliest && start <= latest && free
          minute += AvailabilitySlot::STEP
        end
      end
    end
    starts.sort
  end

  def photo_pending?
    pending_photo.attached?
  end

  # Moves the waiting photo into place. The previous live photo is removed from the bucket.
  def approve_photo!
    return false unless pending_photo.attached?

    photo.attach(pending_photo.blob)
    pending_photo.detach
    update!(photo_rejected_at: nil)
    true
  end

  def reject_photo!
    return false unless pending_photo.attached?

    pending_photo.purge
    update!(photo_rejected_at: Time.current)
    true
  end

  # Removes the live and the waiting photo (moderation, and when an account is deleted).
  def remove_photo!
    photo.purge if photo.attached?
    pending_photo.purge if pending_photo.attached?
  end

  private

  def normalize_fields
    self.gender = nil if gender.blank?
    self.intro_video_url = intro_video_url.to_s.strip.presence
  end

  def pending_photo_rules
    return unless pending_photo.attached?

    blob = pending_photo.blob
    errors.add(:pending_photo, I18n.t("teacher_profiles.photo.errors.type")) unless PHOTO_TYPES.include?(blob.content_type)
    errors.add(:pending_photo, I18n.t("teacher_profiles.photo.errors.size")) if blob.byte_size > PHOTO_MAX_BYTES
  end

  def user_must_be_teacher
    errors.add(:user, :invalid) unless user&.role_teacher?
  end
end
