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

  def snapshot_changed_since_last_track_sync?(current_snapshot_id)
    last_snapshot = last_track_sync_snapshot_id
    last_snapshot.nil? || current_snapshot_id != last_snapshot
  end

  def update_snapshot_if_changed!(new_snapshot_id)
    return if snapshot_id == new_snapshot_id

    update!(snapshot_id: new_snapshot_id)
  end

  def mark_tracks_synced!(current_snapshot_id)
    update!(
      last_track_sync_snapshot_id: current_snapshot_id,
      last_track_synced_at: Time.current
    )
  end
end
