# frozen_string_literal: true

class CreatePlaylists < ActiveRecord::Migration[8.1]
  def change
    create_table :playlists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :spotify_id, null: false
      t.string :name, null: false
      t.text :description
      t.jsonb :raw_data, default: {}, null: false

      t.timestamps
    end

    add_index :playlists, :spotify_id, unique: true
  end
end
