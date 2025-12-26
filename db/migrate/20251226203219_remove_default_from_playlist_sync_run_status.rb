# frozen_string_literal: true

class RemoveDefaultFromPlaylistSyncRunStatus < ActiveRecord::Migration[8.1]
  def up
    change_column_default :playlist_sync_runs, :status, from: 0, to: nil
  end

  def down
    change_column_default :playlist_sync_runs, :status, from: nil, to: 0
  end
end
