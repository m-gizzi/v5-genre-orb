# frozen_string_literal: true

class AddSnapshotIdToPlaylists < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      add_column :playlists, :snapshot_id, :string
      add_index :playlists, :snapshot_id

      reversible do |dir|
        dir.up do
          Playlist.find_each do |playlist|
            playlist.update_column(:snapshot_id, playlist.raw_data['snapshot_id'])
          end
        end
      end
    end
  end
end
