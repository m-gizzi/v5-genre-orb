# frozen_string_literal: true

class Track < ApplicationRecord
  has_many :track_artists, dependent: :destroy
  has_many :artists, through: :track_artists
  has_many :playlist_tracks, dependent: :destroy
  has_many :playlists, through: :playlist_tracks

  validates :spotify_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :raw_data, presence: true
end
