# Certificates are only shown to the teacher who uploaded them and to administrators.
class QualificationDocumentsController < ApplicationController
  def show
    qualification = Qualification.includes(teacher_profile: :user).find(params[:id])
    raise ActiveRecord::RecordNotFound unless allowed?(qualification) && qualification.document.attached?

    blob = qualification.document.blob
    safe_type = Qualification::ALLOWED_CONTENT_TYPES.include?(blob.content_type)

    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Cache-Control"] = "private, no-store"
    send_data qualification.document.download,
              type: safe_type ? blob.content_type : "application/octet-stream",
              disposition: safe_type ? "inline" : "attachment",
              filename: blob.filename.to_s
  end

  private

  def allowed?(qualification)
    current_user.role_admin? || qualification.teacher_profile.user_id == current_user.id
  end
end
