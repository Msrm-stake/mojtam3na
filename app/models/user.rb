class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles a person may pick when signing up. Admins are promoted manually.
  SIGNUP_ROLES = %w[parent teacher].freeze

  # prefix: true gives role_parent?, role_teacher?, role_admin?
  # ("parent" alone clashes with a built-in Active Record method)
  enum :role, { parent: "parent", teacher: "teacher", admin: "admin" }, prefix: true

  has_one :teacher_profile, dependent: :destroy
  has_many :students, foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy
  has_many :consents, dependent: :destroy

  # Set by the sign-up form only, so accounts created by scripts or tests do not need the tick.
  attr_accessor :require_terms_acceptance
  attribute :accept_terms, :boolean

  # Every new teacher starts with a pending profile, reviewed before going live.
  after_create :create_teacher_profile!, if: :role_teacher?
  before_create :record_terms_acceptance, if: :require_terms_acceptance

  validates :first_name, :last_name, presence: true
  validates :accept_terms, acceptance: { accept: true }, allow_nil: false, if: :require_terms_acceptance
  validates :locale, inclusion: { in: ->(_user) { I18n.available_locales.map(&:to_s) } }
  validate :time_zone_must_exist

  def full_name
    [first_name, last_name].compact_blank.join(" ")
  end

  # The person's own time zone (falls back to UTC).
  def zone
    ActiveSupport::TimeZone[time_zone.to_s] || ActiveSupport::TimeZone["UTC"]
  end

  # A deleted account keeps its row (payment records point to it) but can never sign in again.
  def deleted?
    deleted_at.present?
  end

  def active_for_authentication?
    super && !deleted?
  end

  def inactive_message
    deleted? ? :deleted_account : super
  end

  private

  # The date and the version of the legal texts accepted at sign-up.
  def record_terms_acceptance
    self.terms_accepted_at = Time.current
    self.terms_version = Legal.value(:last_updated)
  end

  def time_zone_must_exist
    errors.add(:time_zone, :inclusion) unless ActiveSupport::TimeZone[time_zone.to_s]
  end
end
