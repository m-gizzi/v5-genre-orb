# frozen_string_literal: true

module Spotify
  class AuthPayload
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :spotify_id, :string
    attribute :email, :string
    attribute :display_name, :string
    attribute :token, :string
    attribute :refresh_token, :string
    attribute :expires_at, :integer

    validates :spotify_id, presence: true
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :token, presence: true
    validates :refresh_token, presence: true
    validates :expires_at, presence: true, numericality: { greater_than: 0 }

    def self.from_auth_hash(auth_hash)
      new(
        spotify_id: auth_hash['uid'],
        email: auth_hash.dig('info', 'email'),
        display_name: auth_hash.dig('info', 'display_name'),
        token: auth_hash.dig('credentials', 'token'),
        refresh_token: auth_hash.dig('credentials', 'refresh_token'),
        expires_at: auth_hash.dig('credentials', 'expires_at')
      )
    end

    def to_user_attributes
      {
        spotify_id: spotify_id,
        spotify_email: email,
        spotify_display_name: computed_display_name,
        access_token: token,
        refresh_token: refresh_token,
        token_expires_at: token_expires_at_time
      }
    end

    def computed_display_name
      display_name.presence || email&.split('@')&.first
    end

    def token_expires_at_time
      return nil if expires_at.nil?

      Time.zone.at(expires_at)
    end
  end
end
