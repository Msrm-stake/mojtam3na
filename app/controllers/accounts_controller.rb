class AccountsController < ApplicationController
  before_action :set_deletion

  def show
    @blockers = @deletion.blockers
  end

  # A file with the person's data. The password is asked again, in case the computer is shared.
  def export
    unless current_user.valid_password?(params[:password].to_s)
      return redirect_to(account_path, alert: t(".wrong_password"), status: :see_other)
    end

    send_data JSON.pretty_generate(AccountExport.new(current_user).to_h),
              filename: "mojtam3na-my-data-#{Date.current.iso8601}.json",
              type: "application/json; charset=utf-8",
              disposition: "attachment"
  end

  def destroy
    if params[:confirm] != "1"
      redirect_to account_path, alert: t(".confirm_required"), status: :see_other
    elsif !current_user.valid_password?(params[:password].to_s)
      redirect_to account_path, alert: t(".wrong_password"), status: :see_other
    else
      @deletion.call!
      sign_out(:user)
      redirect_to root_path, notice: t(".deleted"), status: :see_other
    end
  rescue AccountDeletion::Blocked
    redirect_to account_path, alert: t("accounts.destroy.blocked"), status: :see_other
  end

  private

  def set_deletion
    @deletion = AccountDeletion.new(current_user)
  end
end
