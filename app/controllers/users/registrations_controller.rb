module Users
  class RegistrationsController < Devise::RegistrationsController
    # Accounts are closed from the My account page, which keeps legally required payment records.
    def destroy
      redirect_to account_path, alert: t("accounts.use_account_page"), status: :see_other
    end

    protected

    # The sign-up form must carry the tick for the terms of use and the privacy policy.
    def build_resource(hash = {})
      super
      resource.require_terms_acceptance = true
    end
  end
end
