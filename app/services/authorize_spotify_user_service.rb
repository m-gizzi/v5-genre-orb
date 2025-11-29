# frozen_string_literal: true

class AuthorizeSpotifyUserService < ApplicationService
  attr_reader :auth_hash

  def initialize(auth_hash)
    super
    @auth_hash = auth_hash
  end

  def call
    user = User.find_or_initialize_by(spotify_id: auth_hash['uid'])
    user.assign_attributes(user_attributes)
    user.save

    user
  end

  private

  def user_attributes
    {
      spotify_id: auth_hash['uid'],
      spotify_email: info['email'],
      spotify_display_name: info['display_name'] || info['email']&.split('@')&.first,
      access_token: credentials['token'],
      refresh_token: credentials['refresh_token'],
      token_expires_at: calculate_expiration(credentials['expires_at'])
    }
  end

  def credentials
    @credentials ||= auth_hash['credentials']
  end

  def info
    @info ||= auth_hash['info']
  end

  def calculate_expiration(expires_at_timestamp)
    return nil if expires_at_timestamp.nil?

    Time.zone.at(expires_at_timestamp)
  end
end
