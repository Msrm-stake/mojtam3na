module LessonCompletion
  extend ActiveSupport::Concern

  # A lesson counts as completed 24 hours after it ends, which leaves the parent a day to raise a problem.
  COMPLETION_DELAY = 24.hours

  class_methods do
    # Confirms finished lessons and records the teacher's earning for paid ones. Safe to run repeatedly.
    def complete_finished!(now: Time.current)
      completed = 0
      status_scheduled.where("ends_at <= ?", now - COMPLETION_DELAY).find_each do |lesson|
        lesson.with_lock do
          next unless lesson.status_scheduled?

          lesson.update!(status: "completed")
          Earning.record_for!(lesson, now: now)
          completed += 1
        end
      end
      completed
    end
  end
end
