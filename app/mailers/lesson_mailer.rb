# Lesson emails go to both people, each in their own language and time zone.
# Usage: LessonMailer.with(lesson:, recipient:, role: "parent" or "teacher", cancelled_by: "parent" or "teacher").booked
class LessonMailer < ApplicationMailer
  before_action :load_params
  around_action :in_recipient_locale

  def booked
    key = @lesson.trial? ? "subject" : "subject_paid"
    mail(to: @recipient.email,
         subject: t(".#{key}.#{@role}", teacher: public_name(@teacher_user), child: @student.first_name))
  end

  def cancelled
    canceller = params.fetch(:cancelled_by).to_s
    raise ArgumentError, "cancelled_by must be parent or teacher" unless %w[parent teacher].include?(canceller)

    @intro_key = canceller == @role ? "by_you" : "by_#{canceller}"
    mail(to: @recipient.email, subject: t(".subject"))
  end

  def reminder
    mail(to: @recipient.email, subject: t(".subject"))
  end

  private

  def load_params
    @lesson = params.fetch(:lesson)
    @recipient = params.fetch(:recipient)
    @role = params.fetch(:role).to_s
    raise ArgumentError, "role must be parent or teacher" unless %w[parent teacher].include?(@role)

    @student = @lesson.student
    @teacher_user = @lesson.teacher_profile.user
  end

  def in_recipient_locale(&block)
    I18n.with_locale(@recipient.locale, &block)
  end
end
