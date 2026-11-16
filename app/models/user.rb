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

  # Every new teacher starts with a pending profile, reviewed before going live.
  after_create :create_teacher_profile!, if: :role_teacher?

  validates :first_name, :last_name, presence: true
  validates :locale, inclusion: { in: ->(_user) { I18n.available_locales.map(&:to_s) } }
  validate :time_zone_must_exist

  def full_name
    [first_name, last_name].compact_blank.join(" ")
  end

  private

  def time_zone_must_exist
    errors.add(:time_zone, :inclusion) unless ActiveSupport::TimeZone[time_zone.to_s]
  end
end
