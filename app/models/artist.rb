# frozen_string_literal: true

class Artist < ApplicationRecord
  has_many :track_artists, dependent: :destroy
  has_many :tracks, through: :track_artists

  validates :spotify_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :raw_data, presence: true
end
