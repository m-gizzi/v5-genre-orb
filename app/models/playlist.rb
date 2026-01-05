# frozen_string_literal: true

class Playlist < ApplicationRecord
  belongs_to :user
  has_many :playlist_tracks, dependent: :destroy
  has_many :tracks, through: :playlist_tracks
  has_many :track_sync_runs, dependent: :destroy

  validates :spotify_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :raw_data, presence: true

  scope :active, -> { where(archived_at: nil) }

  def mark_tracks_synced!(synced_snapshot_id)
    update!(
      last_track_sync_snapshot_id: synced_snapshot_id,
      last_track_synced_at: Time.current
    )
  end
end
