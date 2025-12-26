# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Playlists::FetchBatchJob do
  let(:user) { create(:user) }
  let(:sync_run) { create(:playlist_sync_run, user: user, status: :processing_batches) }
  let(:offset) { 0 }
  let(:limit) { 50 }
  let(:spotify_client) { instance_double(Spotify::PlaylistClient) }

  let(:playlist_data) do
    [
      {
        spotify_id: 'playlist1',
        name: 'Playlist 1',
        description: 'First playlist',
        raw_data: { 'id' => 'playlist1' }
      },
      {
        spotify_id: 'playlist2',
        name: 'Playlist 2',
        description: 'Second playlist',
        raw_data: { 'id' => 'playlist2' }
      }
    ]
  end

  before do
    allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(spotify_client)
    allow(spotify_client).to receive(:fetch_user_playlists).with(limit: limit, offset: offset).and_return(playlist_data)
  end

  describe '#perform' do
    it 'fetches playlists from Spotify' do
      described_class.perform_now(sync_run.id, offset, limit)
      expect(spotify_client).to have_received(:fetch_user_playlists).with(limit: limit, offset: offset)
    end

    it 'creates playlists that do not exist' do
      expect do
        described_class.perform_now(sync_run.id, offset, limit)
      end.to change { user.playlists.count }.by(2)

      playlist1 = user.playlists.find_by(spotify_id: 'playlist1')
      expect(playlist1.name).to eq('Playlist 1')
      expect(playlist1.description).to eq('First playlist')
      expect(playlist1.archived_at).to be_nil
    end

    it 'updates playlists that already exist' do
      existing = create(:playlist, user: user, spotify_id: 'playlist1', name: 'Old Name', archived_at: 1.day.ago)

      described_class.perform_now(sync_run.id, offset, limit)

      existing.reload
      expect(existing.name).to eq('Playlist 1')
      expect(existing.description).to eq('First playlist')
      expect(existing.archived_at).to be_nil
    end

    it 'unarchives previously archived playlists' do
      archived = create(:playlist, user: user, spotify_id: 'playlist1', archived_at: 1.day.ago)

      described_class.perform_now(sync_run.id, offset, limit)

      expect(archived.reload.archived_at).to be_nil
    end

    it 'increments playlists_processed counter for each playlist' do
      described_class.perform_now(sync_run.id, offset, limit)
      expect(sync_run.reload.playlists_processed).to eq(2)
    end

    it 'increments batch completion' do
      expect(sync_run).to receive(:increment_batch_completion!)
      allow(PlaylistSyncRun).to receive(:find).with(sync_run.id).and_return(sync_run)

      described_class.perform_now(sync_run.id, offset, limit)
    end

    it 'uses lock when incrementing progress counters' do
      # 2 locks for playlists_processed + 1 lock for increment_batch_completion!
      expect(sync_run).to receive(:with_lock).exactly(3).times.and_call_original
      allow(PlaylistSyncRun).to receive(:find).with(sync_run.id).and_return(sync_run)

      described_class.perform_now(sync_run.id, offset, limit)
    end

    context 'when batch is empty' do
      before do
        allow(spotify_client).to receive(:fetch_user_playlists).and_return([])
      end

      it 'does not create any playlists' do
        expect do
          described_class.perform_now(sync_run.id, offset, limit)
        end.not_to change { user.playlists.count }
      end

      it 'still completes the batch' do
        expect(sync_run).to receive(:increment_batch_completion!)
        allow(PlaylistSyncRun).to receive(:find).with(sync_run.id).and_return(sync_run)

        described_class.perform_now(sync_run.id, offset, limit)
      end

      it 'does not increment playlists_processed' do
        described_class.perform_now(sync_run.id, offset, limit)
        expect(sync_run.reload.playlists_processed).to eq(0)
      end
    end

    context 'when rate limit cooldown is active' do
      before do
        allow(spotify_client).to receive(:fetch_user_playlists)
          .and_raise(Spotify::Errors::RateLimitCooldownActive.new('Rate limited', retry_after: 60))
      end

      it 'does not create any playlists' do
        job = described_class.new(sync_run.id, offset, limit)
        expect do
          begin
            job.send(:perform, sync_run.id, offset, limit)
          rescue Spotify::Errors::RateLimitCooldownActive
            # Expected error - handled by SpotifyJobErrorHandling
          end
        end.not_to change { user.playlists.count }
      end
    end

    context 'when Spotify returns 429 Too Many Requests' do
      before do
        allow(spotify_client).to receive(:fetch_user_playlists)
          .and_raise(Spotify::Errors::RateLimitError.new('Rate limit exceeded', retry_after: 120))
      end

      it 'does not create any playlists' do
        job = described_class.new(sync_run.id, offset, limit)
        expect do
          begin
            job.send(:perform, sync_run.id, offset, limit)
          rescue Spotify::Errors::RateLimitError
            # Expected error - handled by SpotifyJobErrorHandling
          end
        end.not_to change { user.playlists.count }
      end
    end

    context 'with custom limit' do
      let(:limit) { 20 }

      it 'passes custom limit to Spotify client' do
        described_class.perform_now(sync_run.id, offset, limit)
        expect(spotify_client).to have_received(:fetch_user_playlists).with(limit: 20, offset: offset)
      end
    end

    context 'with custom offset' do
      let(:offset) { 100 }

      it 'passes custom offset to Spotify client' do
        described_class.perform_now(sync_run.id, offset, limit)
        expect(spotify_client).to have_received(:fetch_user_playlists).with(limit: limit, offset: 100)
      end
    end
  end

  describe 'retry behavior' do
    it 'includes SpotifyJobErrorHandling concern' do
      expect(described_class.ancestors).to include(SpotifyJobErrorHandling)
    end
  end
end
