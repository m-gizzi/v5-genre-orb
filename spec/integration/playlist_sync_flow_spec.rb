# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Playlist sync flow' do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:spotify_client) { instance_double(Spotify::PlaylistClient) }

  before do
    allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(spotify_client)
  end

  describe 'full sync from start to finish' do
    let(:playlists_batch1) do
      Array.new(50) do |i|
        {
          spotify_id: "playlist#{i}",
          name: "Playlist #{i}",
          description: "Description #{i}",
          raw_data: { 'id' => "playlist#{i}" }
        }
      end
    end

    let(:playlists_batch2) do
      Array.new(25) do |i|
        {
          spotify_id: "playlist#{i + 50}",
          name: "Playlist #{i + 50}",
          description: "Description #{i + 50}",
          raw_data: { 'id' => "playlist#{i + 50}" }
        }
      end
    end

    before do
      allow(spotify_client).to receive(:fetch_user_playlists)
        .with(limit: 50, offset: 0).and_return({
          playlists: playlists_batch1,
          pagination: { total: 75, limit: 50, offset: 0, next: 'next_url', previous: nil }
        })
      allow(spotify_client).to receive(:fetch_user_playlists)
        .with(limit: 50, offset: 50).and_return({
          playlists: playlists_batch2,
          pagination: { total: 75, limit: 50, offset: 50, next: nil, previous: 'prev_url' }
        })
    end

    it 'completes full sync from start to finish' do
      sync_run = nil

      perform_enqueued_jobs do
        sync_run = Playlists::StartSyncService.call(user)
      end

      expect(sync_run.reload).to be_completed
      expect(sync_run.completed_at).not_to be_nil
    end

    it 'creates all playlists from Spotify' do
      perform_enqueued_jobs do
        Playlists::StartSyncService.call(user)
      end

      expect(user.playlists.count).to eq(75)
      expect(user.playlists.where(archived_at: nil).count).to eq(75)
    end

    it 'sets correct playlist attributes' do
      perform_enqueued_jobs do
        Playlists::StartSyncService.call(user)
      end

      playlist = user.playlists.find_by(spotify_id: 'playlist0')
      expect(playlist.name).to eq('Playlist 0')
      expect(playlist.description).to eq('Description 0')
      expect(playlist.raw_data['spotify_id']).to eq('playlist0')
    end

    it 'updates progress counters correctly' do
      sync_run = nil

      perform_enqueued_jobs do
        sync_run = Playlists::StartSyncService.call(user)
      end

      sync_run.reload
      expect(sync_run.playlists_processed).to eq(75)
      expect(sync_run.batches_completed).to eq(2)
      expect(sync_run.batches_total).to eq(2)
    end

    it 'creates sync items for all playlists' do
      sync_run = nil

      perform_enqueued_jobs do
        sync_run = Playlists::StartSyncService.call(user)
      end

      expect(sync_run.playlist_sync_items.count).to eq(75)
      expect(sync_run.playlists.count).to eq(75)
    end

    context 'when playlists already exist' do
      let!(:existing_playlist) do
        create(:playlist, user: user, spotify_id: 'playlist0', name: 'Old Name', description: 'Old Description')
      end

      it 'updates existing playlists' do
        perform_enqueued_jobs do
          Playlists::StartSyncService.call(user)
        end

        existing_playlist.reload
        expect(existing_playlist.name).to eq('Playlist 0')
        expect(existing_playlist.description).to eq('Description 0')
      end

      it 'does not create duplicate playlists' do
        perform_enqueued_jobs do
          Playlists::StartSyncService.call(user)
        end

        expect(user.playlists.where(spotify_id: 'playlist0').count).to eq(1)
      end
    end

    context 'when some playlists were deleted from Spotify' do
      let!(:playlist_still_exists) do
        create(:playlist, user: user, spotify_id: 'playlist0', archived_at: nil)
      end
      let!(:playlist_deleted_from_spotify) do
        create(:playlist, user: user, spotify_id: 'deleted_playlist', archived_at: nil)
      end

      it 'archives playlists not found in Spotify' do
        perform_enqueued_jobs do
          Playlists::StartSyncService.call(user)
        end

        expect(playlist_deleted_from_spotify.reload.archived_at).not_to be_nil
      end

      it 'does not archive playlists that still exist in Spotify' do
        perform_enqueued_jobs do
          Playlists::StartSyncService.call(user)
        end

        expect(playlist_still_exists.reload.archived_at).to be_nil
      end
    end

    context 'when user has fewer than 50 playlists' do
      let(:small_batch) do
        Array.new(10) do |i|
          {
            spotify_id: "playlist#{i}",
            name: "Playlist #{i}",
            description: nil,
            raw_data: {}
          }
        end
      end

      before do
        allow(spotify_client).to receive(:fetch_user_playlists)
          .with(limit: 50, offset: 0).and_return({
            playlists: small_batch,
            pagination: { total: 10, limit: 50, offset: 0, next: nil, previous: nil }
          })
      end

      it 'completes sync successfully' do
        sync_run = nil

        perform_enqueued_jobs do
          sync_run = Playlists::StartSyncService.call(user)
        end

        expect(sync_run.reload).to be_completed
        expect(user.playlists.count).to eq(10)
      end
    end

    context 'when user has no playlists' do
      before do
        allow(spotify_client).to receive(:fetch_user_playlists)
          .with(limit: 50, offset: 0).and_return({
            playlists: [],
            pagination: { total: 0, limit: 50, offset: 0, next: nil, previous: nil }
          })
      end

      it 'completes sync successfully' do
        sync_run = nil

        perform_enqueued_jobs do
          sync_run = Playlists::StartSyncService.call(user)
        end

        expect(sync_run.reload).to be_completed
        expect(user.playlists.count).to eq(0)
      end
    end
  end

  describe 'concurrent sync requests' do
    let(:playlists) do
      Array.new(10) do |i|
        { spotify_id: "playlist#{i}", name: "Playlist #{i}", description: nil, raw_data: {} }
      end
    end

    before do
      allow(spotify_client).to receive(:fetch_user_playlists)
        .with(limit: 50, offset: 0).and_return({
          playlists: playlists,
          pagination: { total: 10, limit: 50, offset: 0, next: nil, previous: nil }
        })
    end

    it 'prevents duplicate syncs for same user' do
      # Don't use perform_enqueued_jobs - we want to test the duplicate prevention
      # logic without completing the first sync
      sync_run1 = Playlists::StartSyncService.call(user)
      sync_run2 = Playlists::StartSyncService.call(user)

      # Should return same sync_run
      expect(sync_run1.id).to eq(sync_run2.id)
      expect(PlaylistSyncRun.where(user: user).count).to eq(1)
    end
  end
end
