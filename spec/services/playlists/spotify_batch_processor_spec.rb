# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Playlists::SpotifyBatchProcessor do
  let(:user) { create(:user) }
  let(:sync_run) { create(:playlist_sync_run, user: user) }
  let(:processor) { described_class.new(sync_run: sync_run) }

  describe '#process_batch' do
    let(:playlists) do
      [
        {
          spotify_id: 'p1',
          name: 'Playlist 1',
          description: 'First',
          raw_data: { 'id' => 'p1' }
        },
        {
          spotify_id: 'p2',
          name: 'Playlist 2',
          description: 'Second',
          raw_data: { 'id' => 'p2' }
        }
      ]
    end

    it 'creates playlists that do not exist' do
      expect { processor.process_batch(playlists) }
        .to change { user.playlists.count }.by(2)
    end

    it 'updates existing playlists' do
      existing = create(:playlist, user: user, spotify_id: 'p1', name: 'Old Name')

      processor.process_batch(playlists)

      expect(existing.reload.name).to eq('Playlist 1')
    end

    it 'increments playlists_processed counter' do
      processor.process_batch(playlists)
      expect(sync_run.reload.playlists_processed).to eq(2)
    end

    it 'creates sync items for each playlist' do
      processor.process_batch(playlists)
      expect(PlaylistSyncItem.where(playlist_sync_run: sync_run).count).to eq(2)
    end

    it 'unarchives previously archived playlists' do
      archived = create(:playlist, user: user, spotify_id: 'p1', archived_at: 1.day.ago)

      processor.process_batch(playlists)

      expect(archived.reload.archived_at).to be_nil
    end
  end

  describe '#mark_batch_complete!' do
    it 'increments batches_completed' do
      expect { processor.mark_batch_complete! }
        .to change { sync_run.reload.batches_completed }.by(1)
    end
  end
end
