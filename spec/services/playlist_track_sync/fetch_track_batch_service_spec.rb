# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaylistTrackSync::FetchTrackBatchService do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user) }
  let(:sync_run) { create(:track_sync_run, playlist: playlist) }
  let(:spotify_client) { instance_double(Spotify::TrackClient) }
  let(:service) { described_class.new(sync_run: sync_run, offset: 100, limit: 100) }

  let(:tracks) { generate_track_items(count: 100, starting_index: 100, artists_per_track: 2) }
  let(:response) do
    build_spotify_tracks_response(
      track_items: tracks,
      total: 250,
      offset: 100,
      next_url: 'https://api.spotify.com/v1/playlists/playlist123/tracks?offset=200&limit=100',
      prev_url: 'https://api.spotify.com/v1/playlists/playlist123/tracks?offset=0&limit=100'
    )
  end

  before do
    allow(Spotify::TrackClient).to receive(:for_user).with(user).and_return(spotify_client)
    allow(spotify_client).to receive(:fetch_playlist_tracks)
      .with(playlist, limit: 100, offset: 100).and_return(response)
  end

  it 'processes the batch' do
    expect { service.call }.to change { Track.count }.by(100)
  end

  it 'creates artists from track data' do
    expect { service.call }.to change { Artist.count }.by_at_least(100)
  end

  it 'creates track-artist associations' do
    expect { service.call }.to change { TrackArtist.count }.by_at_least(100)
  end

  it 'creates playlist-track associations' do
    expect { service.call }.to change { PlaylistTrack.count }.by(100)
  end

  it 'marks batch as complete' do
    expect { service.call }
      .to change { sync_run.reload.batches_completed }.by(1)
  end

  it 'increments tracks_processed counter' do
    service.call
    expect(sync_run.reload.tracks_processed).to eq(100)
  end

  it 'increments artists_processed counter' do
    service.call
    expect(sync_run.reload.artists_processed).to be >= 100
  end

  context 'when track already exists' do
    let!(:existing_track) { create(:track, spotify_id: 'track100') }

    it 'does not create duplicate tracks' do
      expect { service.call }.to change { Track.count }.by(99)
    end

    it 'updates existing track data' do
      service.call
      expect(existing_track.reload.name).to eq('Track 100')
    end
  end

  context 'when artist already exists' do
    let!(:existing_artist) { create(:artist, spotify_id: 'artist100_0') }

    it 'does not create duplicate artists' do
      initial_count = Artist.count
      service.call
      # Should create 199 artists since artist100_0 already exists (100 tracks × 2 artists - 1 existing)
      expect(Artist.count - initial_count).to eq(199)
    end
  end
end
