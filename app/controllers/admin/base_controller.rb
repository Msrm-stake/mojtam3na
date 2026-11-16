module Admin
  class BaseController < ApplicationController
    before_action :require_admin!

    private

    def require_admin!
      redirect_to root_path, alert: t("admin.not_allowed") unless current_user.role_admin?
    end
  end
end
