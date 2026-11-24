# Short emails to the site owner, so new teachers and new documents do not wait unnoticed for approval.
class AdminMailer < ApplicationMailer
  def new_teacher(user)
    @user = user
    @profile = user.teacher_profile
    mail(to: recipient, subject: "[Mojtam3na] New teacher waiting for approval")
  end

  def qualification_added(qualification)
    @qualification = qualification
    @profile = qualification.teacher_profile
    @user = @profile.user
    mail(to: recipient, subject: "[Mojtam3na] New qualification document to verify")
  end

  private

  def recipient
    ENV.fetch("ADMIN_NOTIFY_EMAIL", "contact@mojtam3na.com")
  end
end
