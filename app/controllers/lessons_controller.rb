class LessonsController < ApplicationController
  before_action :set_teacher, only: %i[new create]
  before_action :require_parent!, only: %i[new create]

  def index
    scope =
      if current_user.role_teacher?
        Lesson.where(teacher_profile_id: current_user.teacher_profile&.id)
      elsif current_user.role_parent?
        Lesson.where(booked_by_id: current_user.id)
      else
        Lesson.none
      end

    scope = scope.includes(:student, teacher_profile: :user)
    @upcoming = scope.upcoming.order(:starts_at)
    @history = scope.history.order(starts_at: :desc).limit(50)
  end

  def new
    return redirect_to(new_student_path, alert: t(".add_child_first")) if current_user.students.none?

    prepare_booking_page
  end

  def create
    @lesson = Lesson.new(
      teacher_profile: @profile,
      booked_by: current_user,
      student: current_user.students.find_by(id: lesson_params[:student_id]),
      starts_at: parse_time(lesson_params[:starts_at]),
      trial: true,
      currency: @profile.currency
    )

    saved =
      begin
        @lesson.save
      rescue ActiveRecord::RecordNotUnique
        # Someone else booked this exact time a moment ago.
        @lesson.errors.add(:base, :slot_taken)
        false
      end

    if saved
      redirect_to lessons_path, notice: t(".booked"), status: :see_other
    else
      prepare_booking_page
      render :new, status: :unprocessable_entity
    end
  end

  def cancel
    lesson = Lesson.where(booked_by_id: current_user.id)
                   .or(Lesson.where(teacher_profile_id: current_user.teacher_profile&.id))
                   .find(params[:id])

    if lesson.cancellable_by?(current_user)
      lesson.cancel!(current_user)
      redirect_to lessons_path, notice: t(".cancelled"), status: :see_other
    else
      redirect_to lessons_path, alert: t(".too_late"), status: :see_other
    end
  end

  private

  # Only approved teachers can be booked; anything else is a 404.
  def set_teacher
    @profile = TeacherProfile.status_approved.includes(:user).find(params[:teacher_id])
  end

  def require_parent!
    redirect_to root_path, alert: t("lessons.parents_only") unless current_user.role_parent?
  end

  def lesson_params
    params.fetch(:lesson, {}).permit(:student_id, :starts_at)
  end

  def parse_time(value)
    Time.iso8601(value.to_s).utc
  rescue ArgumentError
    nil
  end

  def prepare_booking_page
    @students = current_user.students.order(:first_name)
    @zone = current_user.zone
    chosen = (params.dig(:lesson, :student_id) || params[:student_id]).to_i
    @student_id = @students.exists?(id: chosen) ? chosen : @students.first&.id
    @days = @profile.bookable_starts.group_by { |time| time.in_time_zone(@zone).to_date }
  end
end
