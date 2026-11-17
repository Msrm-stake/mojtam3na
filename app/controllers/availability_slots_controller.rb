class AvailabilitySlotsController < ApplicationController
  before_action :require_teacher!
  before_action :set_profile

  def index
    @slot = AvailabilitySlot.new(weekday: 1, start_minute: 540, end_minute: 720)
    load_schedule
  end

  def create
    @slot = @profile.availability_slots.build(slot_params)

    if @slot.save
      redirect_to availability_slots_path, notice: t(".created")
    else
      load_schedule
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @profile.availability_slots.find(params[:id]).destroy
    redirect_to availability_slots_path, notice: t(".destroyed"), status: :see_other
  end

  def update_time_zone
    zone = params[:time_zone].to_s

    if ActiveSupport::TimeZone[zone] && current_user.update(time_zone: zone)
      redirect_to availability_slots_path, notice: t(".saved"), status: :see_other
    else
      redirect_to availability_slots_path, alert: t(".invalid"), status: :see_other
    end
  end

  private

  def require_teacher!
    redirect_to root_path, alert: t("teacher_profiles.not_a_teacher") unless current_user.role_teacher?
  end

  def set_profile
    @profile = current_user.teacher_profile || current_user.create_teacher_profile!
  end

  def load_schedule
    @slots_by_day = @profile.availability_slots.order(:start_minute).group_by(&:weekday)
  end

  def slot_params
    params.require(:availability_slot).permit(:weekday, :start_minute, :end_minute)
  end
end
