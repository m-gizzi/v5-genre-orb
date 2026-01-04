# frozen_string_literal: true

class TrackSyncRun < ApplicationRecord
  include SyncRunStateMachine

  belongs_to :playlist
  has_many :track_sync_items, dependent: :destroy
  has_many :tracks, through: :track_sync_items

  def self.in_progress_for_playlist(playlist)
    in_progress.find_by(playlist: playlist)
  end

  private

  def enqueue_cleanup_job
    PlaylistTrackSync::CleanupRemovedJob.perform_later(id)
  end

  def on_completion
    playlist.mark_tracks_synced!(playlist.snapshot_id)
  end
end
