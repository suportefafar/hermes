Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin session
  get    "login",  to: "sessions#new",     as: :login
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Dashboard
  namespace :dashboard do
    root to: "home#index"

    resources :messages, only: %i[index show] do
      member { post :resend }
    end

    resources :clients, only: %i[index new create show] do
      member { patch :toggle_active }
    end

    resources :providers, only: %i[index new create edit update destroy] do
      member { patch :toggle_active }
    end

    resource :settings, only: %i[edit update]
  end

  # Redirect root to dashboard
  root to: redirect("/dashboard")

  # Public API
  namespace :api do
    namespace :v1 do
      resources :messages, only: %i[create]
    end
  end
end
