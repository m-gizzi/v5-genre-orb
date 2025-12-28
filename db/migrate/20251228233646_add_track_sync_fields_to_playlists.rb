# frozen_string_literal: true

class AddTrackSyncFieldsToPlaylists < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      add_column :playlists, :last_track_sync_snapshot_id, :string
      add_column :playlists, :last_track_synced_at, :datetime
      add_index :playlists, :last_track_sync_snapshot_id
    end
  end
end
