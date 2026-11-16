class Subject < ApplicationRecord
  has_many :teacher_subjects, dependent: :destroy
  has_many :teacher_profiles, through: :teacher_subjects

  validates :slug, :name, presence: true
  validates :slug, uniqueness: true
end
