# frozen_string_literal: true

class CreatePlaylistSyncItems < ActiveRecord::Migration[8.1]
  def change
    create_table :playlist_sync_items do |t|
      t.references :playlist_sync_run, null: false, foreign_key: true, index: true
      t.references :playlist, null: false, foreign_key: true, index: true

      t.timestamps

      t.index [:playlist_sync_run_id, :playlist_id],
              unique: true,
              name: 'index_sync_items_on_sync_run_and_playlist_unique'
    end
  end
end
