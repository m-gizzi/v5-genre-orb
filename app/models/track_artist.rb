# frozen_string_literal: true

class TrackArtist < ApplicationRecord
  belongs_to :track
  belongs_to :artist

  validates :track_id, uniqueness: { scope: :artist_id }
end
