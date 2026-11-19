class EarningsController < ApplicationController
  before_action :require_teacher!
  before_action :set_profile

  def show
    load_page
  end

  # Only the payout method and details can be changed here. An empty details field keeps what was saved.
  def payout
    attributes = payout_params.to_h
    attributes.delete("payout_details") if attributes["payout_details"].blank? && @profile.payout_details.present?

    if @profile.update(attributes)
      redirect_to earnings_path, notice: t(".saved"), status: :see_other
    else
      load_page
      render :show, status: :unprocessable_entity
    end
  end

  private

  def require_teacher!
    redirect_to root_path, alert: t("teacher_profiles.not_a_teacher") unless current_user.role_teacher?
  end

  def set_profile
    @profile = current_user.teacher_profile || current_user.create_teacher_profile!
  end

  def load_page
    @summary = @profile.earnings_summary
    @earnings = @profile.earnings.includes(:lesson).order(earned_at: :desc).limit(100)
    @payouts = @profile.payouts.order(period_start: :desc, id: :desc).limit(24)
  end

  def payout_params
    params.require(:teacher_profile).permit(:payout_method, :payout_details)
  end
end
