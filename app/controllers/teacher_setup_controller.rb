class TeacherSetupController < ApplicationController
  STEPS = %w[availability picture headline bio experience rate languages subjects certificate submit].freeze

  before_action :require_teacher!
  before_action :set_profile
  before_action :require_unsubmitted

  def show
    @step = params[:done].present? && @profile.submitted? ? "done" : (requested_step || first_incomplete)
    @errors = []
  end

  def update
    @step = params[:step].to_s
    return redirect_to(teacher_setup_path, status: :see_other) unless STEPS.include?(@step)

    @errors = save_step(@step)
    if @errors.any?
      render :show, status: :unprocessable_entity
    elsif @step == "submit"
      redirect_to teacher_setup_path(done: 1), status: :see_other
    else
      redirect_to teacher_setup_path, status: :see_other
    end
  end

  private

  def require_teacher!
    redirect_to root_path, alert: t("teacher_profiles.not_a_teacher") unless current_user.role_teacher?
  end

  def set_profile
    @profile = current_user.teacher_profile || current_user.create_teacher_profile!
  end

  # The pop-up only exists until the profile has been sent for review.
  def require_unsubmitted
    return if @profile.status_pending? && !@profile.submitted?
    return if action_name == "show" && params[:done].present? && @profile.status_pending? && @profile.submitted?

    redirect_to edit_teacher_profile_path
  end

  # A teacher may go back to an earlier step, never ahead of the first unfinished one.
  def requested_step
    wanted = params[:step].to_s
    return unless STEPS.include?(wanted)

    wanted if STEPS.index(wanted) <= STEPS.index(first_incomplete)
  end

  def first_incomplete
    STEPS.find { |step| !done?(step) } || "submit"
  end

  def done?(step)
    profile = @profile
    case step
    when "availability" then profile.availability_slots.exists?
    when "picture" then profile.photo.attached? || profile.pending_photo.attached? || profile.gender.present?
    when "headline" then profile.headline.present?
    when "bio" then profile.bio.present?
    when "experience" then !profile.years_experience.nil?
    when "rate" then profile.hourly_rate_cents.to_i.positive? && profile.min_age.present? && profile.max_age.present?
    when "languages" then profile.teacher_languages.exists?
    when "subjects" then profile.teacher_subjects.exists?
    when "certificate" then profile.qualifications.exists? || session[:setup_cert_later].present?
    else false
    end
  end

  def attrs
    params.fetch(:teacher_profile, {}).permit(:headline, :bio, :gender, :years_experience, :hourly_rate,
                                              :min_age, :max_age, :pending_photo)
  end

  # Returns a list of error messages; an empty list means the step was saved.
  def save_step(step)
    case step
    when "availability" then save_availability
    when "picture" then save_picture
    when "headline" then save_text(:headline)
    when "bio" then save_text(:bio)
    when "experience" then save_experience
    when "rate" then save_rate
    when "languages" then save_choices(:language_ids, Language, :languages)
    when "subjects" then save_choices(:subject_ids, Subject, :subjects)
    when "certificate"
      session[:setup_cert_later] = true
      []
    when "submit" then save_submit
    end
  end

  def update_profile(values)
    @profile.update(values) ? [] : @profile.errors.full_messages
  end

  def save_text(field)
    value = attrs[field].to_s.strip
    return [t("teacher_setup.steps.#{field}.error")] if value.blank?

    update_profile(field => value)
  end

  def save_experience
    value = attrs[:years_experience].to_s.strip
    unless value.match?(/\A\d{1,2}\z/) && value.to_i <= 60
      return [t("teacher_setup.steps.experience.error")]
    end

    update_profile(years_experience: value.to_i)
  end

  def save_rate
    rate = attrs[:hourly_rate].to_s.strip.tr(",", ".")
    min = attrs[:min_age].to_s.strip
    max = attrs[:max_age].to_s.strip
    errors = []
    errors << t("teacher_setup.steps.rate.rate_error") unless rate.match?(/\A\d+(\.\d{1,2})?\z/) && rate.to_d.positive?
    ages_ok = min.match?(/\A\d+\z/) && max.match?(/\A\d+\z/) &&
              min.to_i.between?(3, 18) && max.to_i.between?(3, 18) && min.to_i <= max.to_i
    errors << t("teacher_setup.steps.rate.ages_error") unless ages_ok
    return errors if errors.any?

    update_profile(hourly_rate: rate, min_age: min.to_i, max_age: max.to_i)
  end

  def save_choices(param, model, step_key)
    ids = Array(params.dig(:teacher_profile, param)).reject(&:blank?)
    valid = model.where(id: ids).pluck(:id)
    return [t("teacher_setup.steps.#{step_key}.error")] if valid.empty?

    @profile.public_send("#{param}=", valid)
    []
  end

  def save_picture
    new_photo = attrs[:pending_photo].present?
    gender = attrs[:gender].presence_in(%w[female male])
    return [t("teacher_setup.steps.picture.error")] if !new_photo && gender.nil? && !done?("picture")

    values = {}
    values[:pending_photo] = attrs[:pending_photo] if new_photo
    values[:gender] = gender if gender
    errors = update_profile(values)
    @profile.update_column(:photo_rejected_at, nil) if errors.empty? && new_photo
    errors
  end

  def save_availability
    return [] if @profile.availability_slots.exists?

    zone = params[:time_zone].to_s
    current_user.update(time_zone: zone) if ActiveSupport::TimeZone[zone]

    days = params.fetch(:days, {})
    slots = (0..6).filter_map do |weekday|
      day = days[weekday.to_s]
      next unless day && day[:on] == "1"

      AvailabilitySlot.new(teacher_profile: @profile, weekday: weekday,
                           start_minute: day[:from].to_i, end_minute: day[:to].to_i)
    end
    return [t("teacher_setup.steps.availability.none")] if slots.empty?
    return [t("teacher_setup.steps.availability.invalid")] unless slots.all?(&:valid?)

    AvailabilitySlot.transaction { slots.each(&:save!) }
    []
  end

  def save_submit
    missing = @profile.missing_for_submission
    return missing.map { |item| t("teacher_profiles.submit.missing_items.#{item}") } if missing.any?

    @profile.submit_for_review!
    AdminNotifier.new_teacher(current_user)
    session.delete(:setup_cert_later)
    []
  end
end
