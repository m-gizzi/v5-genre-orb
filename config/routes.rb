# frozen_string_literal: true

Rails.application.routes.draw do
  root 'home#index'
  get 'up' => 'rails/health#show', as: :rails_health_check

  get '/auth/spotify/callback', to: 'spotify_auth#callback'
  get '/auth/failure', to: 'spotify_auth#failure'
  get '/auth/success', to: 'spotify_auth#success'
end
