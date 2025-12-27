# frozen_string_literal: true

class RemoveMetadataFromPlaylistSyncRuns < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :playlist_sync_runs, :metadata, :jsonb }
  end
end
