# frozen_string_literal: true

class RemoveTotalPlaylistsExpectedFromPlaylistSyncRuns < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :playlist_sync_runs, :total_playlists_expected, :integer }
  end
end
