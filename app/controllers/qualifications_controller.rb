class QualificationsController < ApplicationController
  before_action :require_teacher!
  before_action :set_profile

  def new
    @qualification = @profile.qualifications.build
  end

  def create
    @qualification = @profile.qualifications.build(qualification_params)

    if @qualification.save
      redirect_to edit_teacher_profile_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    qualification = @profile.qualifications.find(params[:id])

    if qualification.status_verified?
      redirect_to edit_teacher_profile_path, alert: t(".locked"), status: :see_other
    else
      qualification.destroy
      redirect_to edit_teacher_profile_path, notice: t(".destroyed"), status: :see_other
    end
  end

  private

  def require_teacher!
    redirect_to root_path, alert: t("teacher_profiles.not_a_teacher") unless current_user.role_teacher?
  end

  def set_profile
    @profile = current_user.teacher_profile || current_user.create_teacher_profile!
  end

  # status, verified_by and admin_notes are deliberately not permitted.
  def qualification_params
    params.require(:qualification).permit(:kind, :title, :institution, :year_obtained, :document)
  end
end
