# frozen_string_literal: true

require 'rspotify/oauth'

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :spotify,
           ENV.fetch('SPOTIFY_CLIENT_ID'),
           ENV.fetch('SPOTIFY_CLIENT_SECRET'),
           scope: %w[
             user-read-email
             user-read-private
             playlist-read-private
             playlist-read-collaborative
             playlist-modify-public
             playlist-modify-private
             user-library-read
             user-library-modify
           ].join(' ')
end

OmniAuth.config.request_validation_phase = OmniAuth::AuthenticityTokenProtection.new(key: :_csrf_token)
