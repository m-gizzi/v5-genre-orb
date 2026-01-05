# frozen_string_literal: true

class CreateTrackSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :track_sync_runs do |t|
      t.references :playlist, null: false, foreign_key: true
      t.integer :status, null: false
      t.integer :batches_total, default: 0
      t.integer :batches_completed, default: 0
      t.integer :tracks_processed, default: 0
      t.integer :artists_processed, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end

    add_index :track_sync_runs, %i[playlist_id status]
    add_index :track_sync_runs, :created_at
    add_index :track_sync_runs, :status

    # Only one active sync per playlist
    add_index :track_sync_runs,
              :playlist_id,
              unique: true,
              where: 'status IN (0, 1, 2)',
              name: 'index_track_sync_runs_on_playlist_active_uniqu'
  end
end
