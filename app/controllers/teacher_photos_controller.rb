# Teacher photos live in the private bucket and are served by the site.
# Public: the live photo of an approved teacher. Private: a photo still waiting for review (its owner and admins only).
class TeacherPhotosController < ApplicationController
  skip_before_action :authenticate_user!, only: :show

  def show
    profile = TeacherProfile.status_approved.find(params[:id])
    send_photo(profile.photo, shared_cache: true)
  end

  def pending
    profile = TeacherProfile.find(params[:id])
    raise ActiveRecord::RecordNotFound unless profile.user_id == current_user.id || current_user.role_admin?

    send_photo(profile.pending_photo, shared_cache: false)
  end

  private

  def send_photo(attachment, shared_cache:)
    raise ActiveRecord::RecordNotFound unless attachment.attached?

    blob = attachment.blob
    raise ActiveRecord::RecordNotFound unless TeacherProfile::PHOTO_TYPES.include?(blob.content_type)

    if shared_cache
      expires_in 1.day, public: true
      return unless stale?(etag: blob.checksum, public: true)
    else
      response.headers["Cache-Control"] = "private, no-store"
    end

    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data blob.download, type: blob.content_type, disposition: "inline"
  end
end
