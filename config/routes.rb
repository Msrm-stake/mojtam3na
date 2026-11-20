Rails.application.routes.draw do
  scope "(:locale)", locale: /en|fr|es|it|ru|ar/ do
    devise_for :users, controllers: { registrations: "users/registrations" }
    root to: "pages#home"

    resource :account, only: %i[show destroy] do
      post :export
    end

    resources :teachers, only: %i[index show] do
      resources :lessons, only: %i[new create]
    end

    resources :lessons, only: :index do
      member do
        patch :cancel
        get :room
      end
    end

    resources :orders, only: [] do
      member do
        get :paid
        get :abandon
      end
    end

    resource :time_zone, only: :update

    resource :teacher_profile, path: "teacher/profile", only: %i[edit update]
    resource :earnings, path: "teacher/earnings", only: :show do
      patch :payout
    end
    resources :qualifications, path: "teacher/qualifications", only: %i[new create destroy]
    resources :availability_slots, path: "teacher/availability", only: %i[index create destroy] do
      collection { patch :update_time_zone }
    end
    resources :students, path: "children", except: :show

    namespace :admin do
      root "teacher_profiles#index"

      resources :teacher_profiles, only: %i[index show] do
        member do
          patch :approve
          patch :reject
          patch :suspend
        end
      end

      resources :qualifications, only: [] do
        member do
          patch :verify
          patch :reject
        end
      end

      resources :payouts, only: %i[index show] do
        collection do
          post :prepare
          get :export
        end
        member do
          patch :mark_paid
          patch :cancel
        end
      end
    end
  end

  # Stripe calls this address (no language prefix). Every call is checked against its signature.
  post "stripe/webhooks", to: "stripe_webhooks#create"

  # Health check: returns 200 if the app boots without exceptions.
  get "up" => "rails/health#show", as: :rails_health_check
end
