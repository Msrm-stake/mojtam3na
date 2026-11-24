# Emails from the site owner to a teacher, in the teacher's own language.
# Usage: TeacherMailer.with(profile: teacher_profile).welcome_reminder.deliver_later
class TeacherMailer < ApplicationMailer
  around_action :in_recipient_locale

  def welcome_reminder
    @profile = params.fetch(:profile)
    @user = @profile.user
    @missing = @profile.missing_for_submission.map { |item| t("teacher_profiles.submit.missing_items.#{item}") }
    @case =
      if @profile.status_approved? then :approved
      elsif @missing.any? then :incomplete
      elsif @profile.submitted? then :waiting
      else :ready
      end
    mail(to: @user.email, subject: t(".subject"), reply_to: ENV.fetch("ADMIN_NOTIFY_EMAIL", "contact@mojtam3na.com"))
  end

  # A message written by the admin. The text is shown exactly as written; only the greeting, button and footer are translated.
  def custom_message
    @profile = params.fetch(:profile)
    @user = @profile.user
    @body = params.fetch(:body).to_s
    @missing = params[:include_missing] ? @profile.missing_for_submission.map { |item| t("teacher_profiles.submit.missing_items.#{item}") } : []
    mail(to: @user.email, subject: params.fetch(:subject).to_s, reply_to: ENV.fetch("ADMIN_NOTIFY_EMAIL", "contact@mojtam3na.com"))
  end

  private

  def in_recipient_locale(&block)
    I18n.with_locale(params.fetch(:profile).user.locale, &block)
  end
end
