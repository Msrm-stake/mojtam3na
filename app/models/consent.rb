class Consent < ApplicationRecord
  belongs_to :user
  belongs_to :student, optional: true

  enum :kind, { child_data: "child_data", lesson_recording: "lesson_recording" }, prefix: true, validate: true

  validates :accepted_at, presence: true
end
