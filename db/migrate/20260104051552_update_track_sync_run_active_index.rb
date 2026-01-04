# frozen_string_literal: true

class UpdateTrackSyncRunActiveIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :track_sync_runs,
                 name: 'index_track_sync_runs_on_playlist_active_uniqu',
                 algorithm: :concurrently

    add_index :track_sync_runs,
              :playlist_id,
              unique: true,
              where: '(status = ANY (ARRAY[0, 1, 2, 3]))',
              name: 'index_track_sync_runs_on_playlist_active_uniqu',
              algorithm: :concurrently
  end

  def down
    remove_index :track_sync_runs,
                 name: 'index_track_sync_runs_on_playlist_active_uniqu',
                 algorithm: :concurrently

    add_index :track_sync_runs,
              :playlist_id,
              unique: true,
              where: '(status = ANY (ARRAY[0, 1, 2]))',
              name: 'index_track_sync_runs_on_playlist_active_uniqu',
              algorithm: :concurrently
  end
end
