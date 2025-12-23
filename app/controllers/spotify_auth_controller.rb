# frozen_string_literal: true

class SpotifyAuthController < ApplicationController
  def callback
    auth_hash = request.env['omniauth.auth']
    auth_payload = Spotify::AuthPayload.from_auth_hash(auth_hash)

    return redirect_to auth_failure_path unless auth_payload.valid?

    AuthorizeSpotifyUserService.call(auth_payload)

    redirect_to auth_success_path
  rescue StandardError
    redirect_to root_path, alert: 'An unexpected error occurred during authentication'
  end

  def success; end
end
