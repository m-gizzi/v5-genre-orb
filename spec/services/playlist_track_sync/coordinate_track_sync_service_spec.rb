# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaylistTrackSync::CoordinateTrackSyncService do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user) }
  let(:sync_run) { create(:track_sync_run, playlist: playlist, status: :pending) }
  let(:spotify_client) { instance_double(Spotify::TrackClient) }
  let(:service) { described_class.new(sync_run: sync_run) }

  before do
    allow(Spotify::TrackClient).to receive(:for_user).with(user).and_return(spotify_client)
  end

  context 'when playlist has fewer than 100 tracks' do
    let(:tracks) { generate_track_items(count: 50) }
    let(:response) { build_spotify_tracks_response(track_items: tracks, total: 50) }

    before do
      allow(spotify_client).to receive(:fetch_playlist_tracks)
        .with(playlist, limit: 100, offset: 0).and_return(response)
    end

    it 'processes first batch immediately' do
      expect { service.call }.to change { Track.count }.by(50)
    end

    it 'marks first batch complete' do
      service.call
      expect(sync_run.reload.batches_completed).to eq(1)
    end

    it 'does not enqueue additional jobs' do
      expect { service.call }.not_to have_enqueued_job(PlaylistTrackSync::FetchTrackBatchJob)
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

  context 'when playlist has 250 tracks (3 batches)' do
    let(:tracks) { generate_track_items(count: 100) }
    let(:response) do
      build_spotify_tracks_response(
        track_items: tracks,
        total: 250,
        next_url: 'https://api.spotify.com/v1/playlists/playlist123/tracks?offset=100&limit=100'
      )
    end

    before do
      allow(spotify_client).to receive(:fetch_playlist_tracks)
        .with(playlist, limit: 100, offset: 0).and_return(response)
    end

    it 'sets batches_total to 3' do
      service.call
      expect(sync_run.reload.batches_total).to eq(3)
    end

    it 'processes first 100 tracks' do
      expect { service.call }.to change { Track.count }.by(100)
    end

    it 'enqueues jobs only for batches 1 and 2' do
      expect { service.call }
        .to have_enqueued_job(PlaylistTrackSync::FetchTrackBatchJob).with(sync_run.id, 100, 100)
        .and have_enqueued_job(PlaylistTrackSync::FetchTrackBatchJob).with(sync_run.id, 200, 100)
        .and have_enqueued_job(PlaylistTrackSync::FetchTrackBatchJob).exactly(2).times
    end
  end

  context 'when playlist has 0 tracks' do
    let(:response) { build_spotify_tracks_response(track_items: [], total: 0) }

    before do
      allow(spotify_client).to receive(:fetch_playlist_tracks)
        .with(playlist, limit: 100, offset: 0).and_return(response)
    end

    it 'does not enqueue any batch jobs' do
      expect { service.call }.not_to have_enqueued_job(PlaylistTrackSync::FetchTrackBatchJob)
    end

    it 'marks first (empty) batch as complete' do
      service.call
      expect(sync_run.reload.batches_completed).to eq(1)
    end
  end
end
