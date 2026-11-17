class TimeZonesController < ApplicationController
  def update
    zone = params[:time_zone].to_s

    if ActiveSupport::TimeZone[zone] && current_user.update(time_zone: zone)
      redirect_back_or_to root_path, notice: t(".saved"), status: :see_other
    else
      redirect_back_or_to root_path, alert: t(".invalid"), status: :see_other
    end
  end
end
