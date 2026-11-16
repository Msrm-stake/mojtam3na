class TeacherSubject < ApplicationRecord
  belongs_to :teacher_profile
  belongs_to :subject

  validates :subject_id, uniqueness: { scope: :teacher_profile_id }
end
