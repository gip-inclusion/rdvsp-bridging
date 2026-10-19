Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope "caldav/:public_id", controller: :caldav, format: false do
    match "/", action: :home, via: :all, as: :caldav_home
    match "calendar", action: :calendar, via: :all, as: :caldav_calendar
    match "calendar/:name", action: :event, via: :all, as: :caldav_event, constraints: { name: %r{[^/]+} }
  end
  match ".well-known/caldav", to: redirect("/caldav/"), via: :all

  post "webhooks/pipedrive/:token" => "pipedrive_webhooks#create", as: :pipedrive_webhook

  namespace :admin do
    root "accounts#index"
    get "google/connect" => "google#connect", as: :google_connect
    get "google/callback" => "google#callback", as: :google_callback
    resources :accounts, only: %i[index show new create update] do
      resources :connections, only: %i[new create]
    end
    resources :connections, only: %i[show update] do
      post :reset_password, on: :member
      post :rebuild, on: :member
    end
  end
end
