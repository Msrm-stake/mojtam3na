class ApplicationController < ActionController::Base
  around_action :switch_locale
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  def default_url_options
    { locale: I18n.locale }
  end

  private

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |user_params|
      user_params.permit(:email, :password, :password_confirmation,
                         :first_name, :last_name, :role).tap do |permitted|
        permitted[:role] = "parent" unless User::SIGNUP_ROLES.include?(permitted[:role])
        permitted[:locale] = I18n.locale.to_s
      end
    end

    devise_parameter_sanitizer.permit(
      :account_update,
      keys: %i[first_name last_name time_zone locale country_code phone]
    )
  end
end
