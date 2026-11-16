class Language < ApplicationRecord
  has_many :teacher_languages, dependent: :destroy
  has_many :teacher_profiles, through: :teacher_languages

  validates :code, :name, :native_name, presence: true
  validates :code, uniqueness: true

  scope :alphabetical, -> { order(:name) }
end
