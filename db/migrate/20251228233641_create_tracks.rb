# frozen_string_literal: true

class CreateTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :tracks do |t|
      t.string :spotify_id, null: false
      t.string :name, null: false
      t.integer :duration_ms
      t.integer :disc_number
      t.integer :track_number
      t.boolean :explicit, default: false, null: false
      t.boolean :is_local, default: false, null: false
      t.integer :popularity
      t.string :preview_url
      t.string :isrc
      t.jsonb :raw_data, default: {}, null: false

      t.timestamps
    end
    add_index :tracks, :spotify_id, unique: true
  end
end
