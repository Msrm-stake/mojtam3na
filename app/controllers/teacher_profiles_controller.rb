class TeacherProfilesController < ApplicationController
  before_action :require_teacher!
  before_action :set_profile

  def edit; end

  # The teacher sends the finished profile for review. Anything missing is listed and nothing is sent.
  def submit
    if @profile.status_approved? || @profile.status_suspended?
      return redirect_to(edit_teacher_profile_path, status: :see_other)
    end

    missing = @profile.missing_for_submission
    if missing.any?
      names = missing.map { |item| t("teacher_profiles.submit.missing_items.#{item}") }.to_sentence
      redirect_to edit_teacher_profile_path, alert: t("teacher_profiles.submit.missing", items: names), status: :see_other
    else
      @profile.submit_for_review!
      AdminNotifier.new_teacher(current_user)
      redirect_to edit_teacher_profile_path, notice: t("teacher_profiles.submit.done"), status: :see_other
    end
  end

  def update
    new_photo = params.dig(:teacher_profile, :pending_photo).present?
    if @profile.update(profile_params)
      @profile.update_column(:photo_rejected_at, nil) if new_photo
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
      :min_age, :max_age, :intro_video_url, :pending_photo,
      language_ids: [], subject_ids: []
    )
  end
end
