# frozen_string_literal: true

class PlaylistSyncRun < ApplicationRecord
  include SyncRunStateMachine

  belongs_to :user
  has_many :playlist_sync_items, dependent: :destroy
  has_many :playlists, through: :playlist_sync_items

  validates :playlists_processed, numericality: { greater_than_or_equal_to: 0 }
  validates :batches_total, numericality: { greater_than_or_equal_to: 0 }
  validates :batches_completed, numericality: { greater_than_or_equal_to: 0 }

  def self.in_progress_for_user(user)
    where(user: user).in_progress.first
  end

  private

  def enqueue_cleanup_job
    UserPlaylistSync::ArchiveMissingJob.perform_later(id)
  end
end
