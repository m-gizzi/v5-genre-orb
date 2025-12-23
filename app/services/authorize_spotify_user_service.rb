# frozen_string_literal: true

class AuthorizeSpotifyUserService < ApplicationService
  attr_reader :auth_payload

  def initialize(auth_payload)
    @auth_payload = auth_payload
  end

  def call
    user = User.find_or_initialize_by(spotify_id: auth_payload.spotify_id)
    user.assign_attributes(auth_payload.to_user_attributes)
    user.save

    user
  end
end
