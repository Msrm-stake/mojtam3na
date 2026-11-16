class TeacherProfilesController < ApplicationController
  before_action :require_teacher!
  before_action :set_profile

  def edit; end

  def update
    if @profile.update(profile_params)
      redirect_to edit_teacher_profile_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_teacher!
    redirect_to root_path, alert: t("teacher_profiles.not_a_teacher") unless current_user.role_teacher?
  end

  def set_profile
    @profile = current_user.teacher_profile || current_user.create_teacher_profile!
  end

  # status, approved_by and the other review fields are deliberately not permitted.
  def profile_params
    params.require(:teacher_profile).permit(
      :headline, :bio, :gender, :years_experience, :hourly_rate, :currency,
      :min_age, :max_age, :intro_video_url,
      language_ids: [], subject_ids: []
    )
  end
end
