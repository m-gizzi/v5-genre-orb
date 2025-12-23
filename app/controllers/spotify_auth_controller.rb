# frozen_string_literal: true

class SpotifyAuthController < ApplicationController
  def callback
    auth_hash = request.env['omniauth.auth']
    auth_payload = Spotify::AuthPayload.from_auth_hash(auth_hash)

    unless auth_payload.valid?
      return redirect_to auth_failure_path, alert: 'Invalid authentication response from Spotify'
    end

    AuthorizeSpotifyUserService.call(auth_payload)

    redirect_to auth_success_path
  rescue StandardError
    redirect_to auth_failure_path, alert: 'An unexpected error occurred during authentication'
  end

  def failure
    error_type = params[:message]
    message = user_friendly_error_message(error_type)
    redirect_to root_path, alert: message
  end

  def success; end

  private

  def user_friendly_error_message(error_type)
    case error_type
    when 'access_denied'
      'You denied access to your Spotify account. Please try again and approve the permissions.'
    when 'invalid_credentials'
      'Invalid Spotify credentials. Please contact support.'
    else
      'Authentication failed. Please try again.'
    end
  end
end
