# frozen_string_literal: true

class PlaylistSyncItem < ApplicationRecord
  belongs_to :playlist_sync_run
  belongs_to :playlist

  validates :playlist_sync_run_id, uniqueness: { scope: :playlist_id }
end
