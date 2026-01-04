# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Playlists::CoordinatePlaylistSyncService do
  let(:user) { create(:user) }
  let(:sync_run) { create(:playlist_sync_run, user: user, status: :pending) }
  let(:spotify_client) { instance_double(Spotify::PlaylistClient) }
  let(:service) { described_class.new(sync_run: sync_run) }

  before do
    allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(spotify_client)
  end

  context 'when user has fewer than 50 playlists' do
    let(:playlists) do
      Array.new(25) do |i|
        { 'id' => "playlist#{i}", 'name' => "Playlist #{i}", 'description' => nil }
      end
    end

    let(:response) do
      {
        items: playlists,
        pagination: {
          total: 25,
          limit: 50,
          offset: 0,
          next: nil,
          previous: nil
        }
      }
    end

    before do
      allow(spotify_client).to receive(:fetch_user_playlists)
        .with(limit: 50, offset: 0).and_return(response)
    end

    it 'sets accurate total from pagination' do
      service.call
      expect(sync_run.reload.total_playlists_expected).to eq(25)
    end

    it 'processes first batch immediately' do
      expect { service.call }.to change { user.playlists.count }.by(25)
    end

    it 'marks first batch complete' do
      service.call
      expect(sync_run.reload.batches_completed).to eq(1)
    end

    it 'does not enqueue additional jobs' do
      expect { service.call }.not_to have_enqueued_job(UserPlaylistSync::FetchPlaylistBatchJob)
    end

    it 'transitions to archiving status after processing single batch' do
      service.call
      expect(sync_run.reload.status).to eq('archiving')
    end

    it 'sets started_at timestamp' do
      freeze_time do
        service.call
        expect(sync_run.reload.started_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  context 'when user has 150 playlists (3 batches)' do
    let(:playlists) do
      Array.new(50) do |i|
        { 'id' => "playlist#{i}", 'name' => "Playlist #{i}", 'description' => nil }
      end
    end

    let(:response) do
      {
        items: playlists,
        pagination: {
          total: 150,
          limit: 50,
          offset: 0,
          next: 'https://api.spotify.com/v1/users/user123/playlists?offset=50&limit=50',
          previous: nil
        }
      }
    end

    before do
      allow(spotify_client).to receive(:fetch_user_playlists)
        .with(limit: 50, offset: 0).and_return(response)
    end

    it 'sets batches_total to 3' do
      service.call
      expect(sync_run.reload.batches_total).to eq(3)
    end

    it 'processes first 50 playlists' do
      expect { service.call }.to change { user.playlists.count }.by(50)
    end

    it 'enqueues jobs only for batches 1 and 2' do
      expect { service.call }
        .to have_enqueued_job(UserPlaylistSync::FetchPlaylistBatchJob).with(sync_run.id, 50, 50)
        .and have_enqueued_job(UserPlaylistSync::FetchPlaylistBatchJob).with(sync_run.id, 100, 50)
        .and have_enqueued_job(UserPlaylistSync::FetchPlaylistBatchJob).exactly(2).times
    end
  end

  context 'when user has 0 playlists' do
    let(:response) do
      {
        items: [],
        pagination: {
          total: 0,
          limit: 50,
          offset: 0,
          next: nil,
          previous: nil
        }
      }
    end

    before do
      allow(spotify_client).to receive(:fetch_user_playlists)
        .with(limit: 50, offset: 0).and_return(response)
    end

    it 'sets total_playlists_expected to 0' do
      service.call
      expect(sync_run.reload.total_playlists_expected).to eq(0)
    end

    it 'does not enqueue any batch jobs' do
      expect { service.call }.not_to have_enqueued_job(UserPlaylistSync::FetchPlaylistBatchJob)
    end

    it 'marks first (empty) batch as complete' do
      service.call
      expect(sync_run.reload.batches_completed).to eq(1)
    end
  end
end
