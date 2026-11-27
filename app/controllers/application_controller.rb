class ApplicationController < ActionController::Base
  around_action :switch_locale
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  # Keeps search engines away until launch (set BLOCK_INDEXING=true on the server).
  after_action :block_search_engines, if: -> { ENV["BLOCK_INDEXING"] == "true" }

  # A storage (S3) problem must not crash the page, and must leave a clear trace in the logs.
  rescue_from "Aws::S3::Errors::ServiceError", with: :storage_unavailable

  def default_url_options
    { locale: I18n.locale }
  end

  private

  # New teachers land on the setup pop-up (after sign-up and after every login)
  # until they have sent their profile for review.
  def after_sign_in_path_for(resource)
    if resource.respond_to?(:role_teacher?) && resource.role_teacher?
      profile = resource.teacher_profile
      return teacher_setup_path if profile && profile.status_pending? && !profile.submitted?
    end
    super
  end

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def block_search_engines
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end

  def storage_unavailable(error)
    Rails.logger.error("File storage error: #{StorageCheck.describe(error)} path=#{request.path}")
    Rails.logger.error(Array(error.backtrace).first(25).join("\n"))
    redirect_back_or_to root_path, alert: t("errors.storage_unavailable"), status: :see_other
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |user_params|
      user_params.permit(:email, :password, :password_confirmation,
                         :first_name, :last_name, :role, :accept_terms).tap do |permitted|
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
