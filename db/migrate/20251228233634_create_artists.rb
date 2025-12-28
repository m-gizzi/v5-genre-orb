# frozen_string_literal: true

class CreateArtists < ActiveRecord::Migration[8.1]
  def change
    create_table :artists do |t|
      t.string :spotify_id, null: false
      t.string :name, null: false
      t.jsonb :raw_data, default: {}, null: false

      t.timestamps
    end
    add_index :artists, :spotify_id, unique: true
    add_index :artists, :name
  end
end
