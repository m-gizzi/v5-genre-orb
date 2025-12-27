# frozen_string_literal: true

class User < ApplicationRecord
  has_many :playlists, dependent: :destroy

  self.filter_attributes = %i[access_token refresh_token]

  validates :spotify_id, presence: true, uniqueness: true

  has_encrypted :access_token, :refresh_token

  def update_spotify_credentials(new_access_token, token_lifetime)
    expires_at = Time.current + token_lifetime.seconds
    update!(
      access_token: new_access_token,
      token_expires_at: expires_at
    )
  end
end
