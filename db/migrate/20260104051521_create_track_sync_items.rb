# frozen_string_literal: true

class CreateTrackSyncItems < ActiveRecord::Migration[8.1]
  def change
    create_table :track_sync_items do |t|
      t.references :track_sync_run, null: false, foreign_key: true, index: true
      t.references :track, null: false, foreign_key: true, index: true

      t.timestamps

      t.index %i[track_sync_run_id track_id],
              unique: true,
              name: 'index_track_sync_items_on_sync_run_and_track_unique'
    end
  end
end
