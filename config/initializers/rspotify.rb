# frozen_string_literal: true

Rails.application.config.to_prepare do
  client_id = ENV.fetch('SPOTIFY_CLIENT_ID', nil) || Rails.application.credentials.dig(:spotify, :client_id)
  client_secret = ENV.fetch('SPOTIFY_CLIENT_SECRET', nil) || Rails.application.credentials.dig(:spotify, :client_secret)

  if client_id.present? && client_secret.present?
    RSpotify.authenticate(client_id, client_secret)
    Rails.logger.debug { 'RSpotify initialized with Spotify API credentials' }
  else
    Rails.logger.warn 'RSpotify credentials not found. Spotify integration will not work.'
  end
end
