Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope "caldav/:public_id", controller: :caldav, format: false do
    match "/", action: :home, via: :all, as: :caldav_home
    match "calendar", action: :calendar, via: :all, as: :caldav_calendar
    match "calendar/:name", action: :event, via: :all, as: :caldav_event, constraints: { name: %r{[^/]+} }
  end
  match ".well-known/caldav", to: redirect("/caldav/"), via: :all

  post "webhooks/pipedrive" => "pipedrive_webhooks#create", as: :pipedrive_webhook

  scope "rdvsp", controller: :rdvsp_authorizations do
    get "authorize/:token", action: :show, as: :rdvsp_authorization_link, constraints: { token: %r{[^/]+} }
    post "authorize/:token", action: :create, constraints: { token: %r{[^/]+} }
    get "callback", action: :callback, as: :rdvsp_callback
  end

  scope "pipedrive", controller: :pipedrive_app do
    get "prendre-rdv", action: :rdv_plan, as: :pipedrive_rdv_plan
    get "retour/:token", action: :back, as: :pipedrive_back, constraints: { token: %r{[^/]+} }
    get "app/callback", action: :callback, as: :pipedrive_app_callback
  end

  namespace :admin do
    root "accounts#index"
    get "google/connect" => "google#connect", as: :google_connect
    get "google/callback" => "google#callback", as: :google_callback
    resources :accounts, only: %i[index show new create update] do
      resources :connections, only: %i[new create]
      resource :rdvsp_authorization, only: :destroy
      resource :rdvsp_organisation, only: %i[edit update]
      resource :rdv_activity_type, only: %i[edit update]
      resources :usager_imports, only: %i[new create]
    end
    resources :connections, only: %i[show update] do
      post :reset_password, on: :member
      post :rebuild, on: :member
      resources :ignored_rdvs, only: %i[new create]
    end
    resources :rdvs, only: [] do
      post :release, on: :member
    end
  end
end
