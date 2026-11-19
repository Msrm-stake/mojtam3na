class Student < ApplicationRecord
  MIN_AGE = 3
  MAX_AGE = 17
  LEVELS = %w[beginner intermediate advanced].freeze

  belongs_to :parent, class_name: "User", inverse_of: :students
  belongs_to :native_language, class_name: "Language", optional: true
  # The consent record is kept as evidence even if the child profile is deleted.
  has_many :consents, dependent: :nullify
  has_many :lessons, dependent: :destroy

  # Runs before the lessons are removed: payment records are never deleted.
  before_destroy :keep_children_with_payments, prepend: true

  enum :arabic_level, LEVELS.index_with(&:itself), prefix: :arabic, validate: true
  enum :quran_level, LEVELS.index_with(&:itself), prefix: :quran, validate: true

  # Ticked by the parent in the form; not stored on the student itself.
  attribute :guardian_consent, :boolean

  before_validation :normalize_fields

  validates :first_name, presence: true, length: { maximum: 50 }
  validates :birth_date, presence: true
  validates :gender, inclusion: { in: %w[female male] }, allow_nil: true
  validates :learning_goals, length: { maximum: 1000 }
  validates :native_language, presence: true, if: -> { native_language_id.present? }
  validates :guardian_consent, acceptance: { accept: true }, allow_nil: false, on: :create
  validate :age_must_be_in_range

  def age(on = Date.current)
    return unless birth_date

    years = on.year - birth_date.year
    years -= 1 if on.month < birth_date.month || (on.month == birth_date.month && on.day < birth_date.day)
    years
  end

  private

  def normalize_fields
    self.first_name = first_name.to_s.strip
    self.gender = nil if gender.blank?
    self.learning_goals = learning_goals.to_s.strip.presence
  end

  def age_must_be_in_range
    return unless birth_date

    errors.add(:birth_date, :age_range, min: MIN_AGE, max: MAX_AGE) unless age.between?(MIN_AGE, MAX_AGE)
  end

  # A child with paid lessons is kept. Orders that were never paid carry no money and are removed with the child.
  def keep_children_with_payments
    records = Order.where(lesson_id: lessons.select(:id))

    if records.where.not(status: "expired").exists?
      errors.add(:base, :has_payments)
      throw :abort
    end

    records.delete_all
  end
end
