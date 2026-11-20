module Users
  class RegistrationsController < Devise::RegistrationsController
    # Accounts are closed from the My account page, which keeps legally required payment records.
    def destroy
      redirect_to account_path, alert: t("accounts.use_account_page"), status: :see_other
    end
  end
end
