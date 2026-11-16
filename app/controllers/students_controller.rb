class StudentsController < ApplicationController
  before_action :require_parent!
  before_action :set_student, only: %i[edit update destroy]

  def index
    @students = current_user.students.includes(:native_language).order(:created_at)
  end

  def new
    @student = current_user.students.build
  end

  def create
    @student = current_user.students.build(student_params)

    if save_with_consent(@student)
      redirect_to students_path, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @student.update(student_params)
      redirect_to students_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @student.destroy
    redirect_to students_path, notice: t(".destroyed"), status: :see_other
  end

  private

  def require_parent!
    redirect_to root_path, alert: t("students.parents_only") unless current_user.role_parent?
  end

  # A parent can only reach their own children (anything else is a 404).
  def set_student
    @student = current_user.students.find(params[:id])
  end

  def student_params
    params.require(:student).permit(
      :first_name, :birth_date, :gender, :native_language_id,
      :arabic_level, :quran_level, :learning_goals, :guardian_consent
    )
end

  # The child and the proof of the parent's consent are saved together or not at all.
  def save_with_consent(student)
    Student.transaction do
      student.save!
      student.consents.create!(user: current_user, kind: "child_data",
                               accepted_at: Time.current, ip_address: request.remote_ip)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
