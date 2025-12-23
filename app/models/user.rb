# frozen_string_literal: true

class User < ApplicationRecord
  has_many :playlists, dependent: :destroy

  self.filter_attributes = %i[access_token refresh_token]

  validates :spotify_id, presence: true, uniqueness: true

  has_encrypted :access_token, :refresh_token
end
