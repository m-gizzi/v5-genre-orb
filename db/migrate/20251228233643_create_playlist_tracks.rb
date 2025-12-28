# frozen_string_literal: true

class CreatePlaylistTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :playlist_tracks do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.datetime :added_at
      t.string :added_by_spotify_id

      t.timestamps
    end

    add_index :playlist_tracks, %i[playlist_id track_id], unique: true
  end
end
