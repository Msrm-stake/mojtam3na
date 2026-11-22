module Admin
  class TeacherProfilesController < BaseController
    before_action :set_profile, only: %i[show approve reject suspend approve_photo reject_photo remove_photo]

    def index
      @status = TeacherProfile.statuses.key?(params[:status]) ? params[:status] : "pending"
      @counts = TeacherProfile.group(:status).count
      @photos_waiting = TeacherProfile.joins(:pending_photo_attachment).includes(:user).order(:id)
      @profiles = TeacherProfile.where(status: @status).includes(:user, :qualifications).order(:created_at)
    end

    def show
      @qualifications = @profile.qualifications.with_attached_document.order(:created_at)
    end

    def approve
      missing = @profile.missing_for_approval

      if missing.empty?
        @profile.approve!(current_user)
        redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.approved"), status: :see_other
      else
        names = missing.map { |item| t("admin.teacher_profiles.missing.#{item}") }.to_sentence
        redirect_to admin_teacher_profile_path(@profile),
                    alert: t("admin.teacher_profiles.cannot_approve", missing: names), status: :see_other
      end
    end

    def reject
      reason = params[:rejection_reason].to_s.strip

      if reason.blank?
        redirect_to admin_teacher_profile_path(@profile), alert: t("admin.teacher_profiles.reason_required"), status: :see_other
      else
        @profile.reject!(reason)
        redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.rejected"), status: :see_other
      end
    end

    def suspend
      @profile.suspend!
      redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.suspended"), status: :see_other
    end

    def approve_photo
      if @profile.approve_photo!
        redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.photo_approved"), status: :see_other
      else
        redirect_to admin_teacher_profile_path(@profile), alert: t("admin.teacher_profiles.photo_none_waiting"), status: :see_other
      end
    end

    def reject_photo
      if @profile.reject_photo!
        redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.photo_rejected"), status: :see_other
      else
        redirect_to admin_teacher_profile_path(@profile), alert: t("admin.teacher_profiles.photo_none_waiting"), status: :see_other
      end
    end

    def remove_photo
      @profile.remove_photo!
      @profile.update!(photo_rejected_at: Time.current)
      redirect_to admin_teacher_profile_path(@profile), notice: t("admin.teacher_profiles.photo_removed"), status: :see_other
    end

    private

    def set_profile
      @profile = TeacherProfile.find(params[:id])
    end
  end
end
