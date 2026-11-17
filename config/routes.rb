Rails.application.routes.draw do
  scope "(:locale)", locale: /en|fr|es|it|ru|ar/ do
    devise_for :users
    root to: "pages#home"

    resources :teachers, only: %i[index show] do
      resources :lessons, only: %i[new create]
    end

    resources :lessons, only: :index do
      member do
        patch :cancel
        get :room
      end
    end

    resource :time_zone, only: :update

    resource :teacher_profile, path: "teacher/profile", only: %i[edit update]
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
    end
  end

  # Health check: returns 200 if the app boots without exceptions.
  get "up" => "rails/health#show", as: :rails_health_check
end
