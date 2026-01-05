# frozen_string_literal: true

class AddLastTrackSyncToPlaylists < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :playlists, :last_track_sync_snapshot_id, :string
    add_column :playlists, :last_track_synced_at, :datetime
    add_index :playlists, :last_track_sync_snapshot_id, algorithm: :concurrently
  end
end
