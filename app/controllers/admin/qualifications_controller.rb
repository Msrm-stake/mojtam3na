module Admin
  class QualificationsController < BaseController
    before_action :set_qualification

    def verify
      @qualification.verify!(current_user)
      redirect_to admin_teacher_profile_path(@qualification.teacher_profile),
                  notice: t("admin.qualifications.verified"), status: :see_other
    end

    def reject
      notes = params[:admin_notes].to_s.strip

      if notes.blank?
        redirect_to admin_teacher_profile_path(@qualification.teacher_profile),
                    alert: t("admin.qualifications.note_required"), status: :see_other
      else
        @qualification.reject!(current_user, notes)
        redirect_to admin_teacher_profile_path(@qualification.teacher_profile),
                    notice: t("admin.qualifications.rejected"), status: :see_other
      end
    end

    private

    def set_qualification
      @qualification = Qualification.find(params[:id])
    end
  end
end
