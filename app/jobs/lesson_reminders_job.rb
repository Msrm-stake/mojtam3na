class LessonRemindersJob < ApplicationJob
  queue_as :default

  # Emails parent and teacher about lessons starting within the next hour.
  # Each lesson is reminded once, even if two runs overlap. Returns how many lessons were handled.
  def perform
    sent = 0

    Lesson.needing_reminder.includes(:student, :booked_by, teacher_profile: :user).find_each do |lesson|
      # Claim the lesson first, so two runs at the same moment can never both send.
      claimed = Lesson.where(id: lesson.id, reminder_sent_at: nil).update_all(reminder_sent_at: Time.current)
      next unless claimed == 1

      begin
        [[lesson.booked_by, "parent"], [lesson.teacher_profile.user, "teacher"]].each do |recipient, role|
          LessonMailer.with(lesson: lesson, recipient: recipient, role: role).reminder.deliver_now
        end
        sent += 1
      rescue StandardError
        # Release the claim so the next run tries again.
        Lesson.where(id: lesson.id).update_all(reminder_sent_at: nil)
        raise
      end
    end

    sent
  end
end
