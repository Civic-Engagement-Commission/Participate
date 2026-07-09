# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Rails 7.1+ built-in health check. Returns 200 if the app booted with no
  # exceptions, 500 otherwise. Used by load balancers / uptime monitors.
  get "up" => "rails/health#show", :as => :rails_health_check

  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  devise_scope :user do
    get "/admin_sign_in", to: "decidim/devise/sessions#new"
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  mount Decidim::Core::Engine => "/"
end
