# frozen_string_literal: true

class AddArchivedAtToPlaylists < ActiveRecord::Migration[8.1]
  def change
    add_column :playlists, :archived_at, :datetime
  end
end
