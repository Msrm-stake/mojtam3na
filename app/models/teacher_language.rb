class TeacherLanguage < ApplicationRecord
  belongs_to :teacher_profile
  belongs_to :language

  enum :proficiency, { native: "native", fluent: "fluent", conversational: "conversational" }, prefix: true

  validates :language_id, uniqueness: { scope: :teacher_profile_id }
end
