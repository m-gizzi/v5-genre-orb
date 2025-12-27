# frozen_string_literal: true

class CreatePlaylistSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :playlist_sync_runs do |t|
      t.references :user, null: false, foreign_key: true, index: true

      t.integer :status, null: false, default: 0

      t.integer :total_playlists_expected, default: 0
      t.integer :playlists_fetched, default: 0
      t.integer :playlists_processed, default: 0
      t.integer :batches_total, default: 0
      t.integer :batches_completed, default: 0

      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.jsonb :metadata, default: {}

      t.timestamps

      t.index %i[user_id status]
      t.index :status
      t.index :created_at

      t.index :user_id,
              unique: true,
              where: 'status IN (0, 1, 2, 3)',
              name: 'index_sync_runs_on_user_active_unique'
    end
  end
end
