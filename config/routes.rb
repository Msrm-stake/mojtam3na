Rails.application.routes.draw do
  scope "(:locale)", locale: /en|fr|es|it|ru|ar/ do
    devise_for :users
    root to: "pages#home"
  end

  # Health check: returns 200 if the app boots without exceptions.
  get "up" => "rails/health#show", as: :rails_health_check
end
