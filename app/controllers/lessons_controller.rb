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
      notify(@lesson, :booked)
      redirect_to lessons_path, notice: t(".booked"), status: :see_other
    else
      prepare_booking_page
      render :new, status: :unprocessable_entity
    end
  end

  def cancel
    lesson = own_lessons.find(params[:id])

    if lesson.cancellable_by?(current_user)
      lesson.cancel!(current_user)
      notify(lesson, :cancelled, cancelled_by: lesson.booked_by_id == current_user.id ? "parent" : "teacher")
      redirect_to lessons_path, notice: t(".cancelled"), status: :see_other
    else
      redirect_to lessons_path, alert: t(".too_late"), status: :see_other
    end
  end

  # The video room. Only the parent who booked and the teacher can open it, and only around the lesson time.
  def room
    @lesson = own_lessons.includes(:student, teacher_profile: :user).find(params[:id])

    unless @lesson.status_scheduled? && Time.current <= @lesson.ends_at + Lesson::JOIN_CLOSES
      return redirect_to(lessons_path, alert: t(".closed"), status: :see_other)
    end

    unless @lesson.join_open?
      return redirect_to(lessons_path, status: :see_other,
                         alert: t(".not_open", minutes: (Lesson::JOIN_OPENS / 1.minute).to_i))
    end

    @join_url = @lesson.join_url_for(current_user)
  rescue DailyClient::Error => e
    Rails.logger.error("Video room error for lesson #{params[:id]}: #{e.message}")
    redirect_to lessons_path, alert: t("lessons.room.unavailable"), status: :see_other
  end

  private

  def own_lessons
    Lesson.where(booked_by_id: current_user.id)
          .or(Lesson.where(teacher_profile_id: current_user.teacher_profile&.id))
  end

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

  # Emails are queued in the background; a mail problem must never undo or block a booking.
  def notify(lesson, kind, cancelled_by: nil)
    [[lesson.booked_by, "parent"], [lesson.teacher_profile.user, "teacher"]].each do |recipient, role|
      LessonMailer.with(lesson: lesson, recipient: recipient, role: role, cancelled_by: cancelled_by)
                  .public_send(kind).deliver_later
    end
  rescue StandardError => e
    Rails.logger.error("Lesson email (#{kind}) could not be queued: #{e.class}: #{e.message}")
  end
end
