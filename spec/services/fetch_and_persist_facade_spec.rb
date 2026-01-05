# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FetchAndPersistFacade do
  let(:user) { create(:user) }

  describe '.user_playlist_batch' do
    let(:playlist_client) { instance_double(Spotify::PlaylistClient) }
    let(:playlist_repository) { instance_double(Spotify::PlaylistRepository) }

    let(:raw_playlists) do
      [
        { 'id' => 'playlist1', 'name' => 'Playlist 1' },
        { 'id' => 'playlist2', 'name' => 'Playlist 2' }
      ]
    end

    let(:client_response) do
      {
        items: raw_playlists,
        pagination: { total: 10, limit: 50, offset: 0, next: nil, previous: nil }
      }
    end

    let(:repository_result) do
      {
        counts: { playlists_processed: 2 },
        item_ids: [1, 2]
      }
    end

    before do
      allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(playlist_client)
      allow(Spotify::PlaylistRepository).to receive(:new).with(user: user).and_return(playlist_repository)
      allow(playlist_client).to receive(:fetch_user_playlists).and_return(client_response)
      allow(playlist_repository).to receive(:process_batch).with(raw_playlists).and_return(repository_result)
    end

    it 'returns item_ids from repository' do
      result = described_class.user_playlist_batch(user: user, limit: 50, offset: 0)
      expect(result[:item_ids]).to eq([1, 2])
    end

    it 'returns counts from repository' do
      result = described_class.user_playlist_batch(user: user, limit: 50, offset: 0)
      expect(result[:counts]).to eq({ playlists_processed: 2 })
    end

    it 'returns pagination from client' do
      result = described_class.user_playlist_batch(user: user, limit: 50, offset: 0)
      expect(result[:pagination]).to eq(client_response[:pagination])
    end

    it 'creates PlaylistClient for user' do
      described_class.user_playlist_batch(user: user, limit: 50, offset: 0)
      expect(Spotify::PlaylistClient).to have_received(:for_user).with(user)
    end

    it 'creates PlaylistRepository with user' do
      described_class.user_playlist_batch(user: user, limit: 50, offset: 0)
      expect(Spotify::PlaylistRepository).to have_received(:new).with(user: user)
    end

    it 'fetches playlists with correct limit and offset' do
      described_class.user_playlist_batch(user: user, limit: 25, offset: 100)
      expect(playlist_client).to have_received(:fetch_user_playlists).with(limit: 25, offset: 100)
    end
  end

  describe '.single_playlist' do
    let(:playlist_client) { instance_double(Spotify::PlaylistClient) }
    let(:playlist_repository) { instance_double(Spotify::PlaylistRepository) }
    let(:spotify_id) { 'playlist123' }

    let(:raw_playlist) do
      { 'id' => spotify_id, 'name' => 'Test Playlist', 'snapshot_id' => 'snap123' }
    end

    let(:repository_result) do
      { counts: { playlists_processed: 1 } }
    end

    before do
      allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(playlist_client)
      allow(Spotify::PlaylistRepository).to receive(:new).with(user: user).and_return(playlist_repository)
      allow(playlist_client).to receive(:fetch_playlist).with(spotify_id).and_return(raw_playlist)
      allow(playlist_repository).to receive(:process_single).with(raw_playlist).and_return(repository_result)
    end

    it 'returns counts from repository' do
      result = described_class.single_playlist(user: user, spotify_id: spotify_id)
      expect(result[:counts]).to eq({ playlists_processed: 1 })
    end

    it 'fetches single playlist by spotify_id' do
      described_class.single_playlist(user: user, spotify_id: spotify_id)
      expect(playlist_client).to have_received(:fetch_playlist).with(spotify_id)
    end

    it 'processes single playlist through repository' do
      described_class.single_playlist(user: user, spotify_id: spotify_id)
      expect(playlist_repository).to have_received(:process_single).with(raw_playlist)
    end
  end

  describe '.playlist_track_batch' do
    let(:playlist) { create(:playlist, user: user) }
    let(:track_client) { instance_double(Spotify::TrackClient) }
    let(:track_repository) { instance_double(Spotify::TrackRepository) }

    let(:raw_tracks) do
      [
        { 'track' => { 'id' => 'track1', 'name' => 'Track 1' } },
        { 'track' => { 'id' => 'track2', 'name' => 'Track 2' } }
      ]
    end

    let(:client_response) do
      {
        items: raw_tracks,
        pagination: { total: 100, limit: 100, offset: 0, next: nil, previous: nil }
      }
    end

    let(:repository_result) do
      {
        counts: { tracks_processed: 2, artists_processed: 3 },
        item_ids: [1, 2]
      }
    end

    before do
      allow(Spotify::TrackClient).to receive(:for_user).with(user).and_return(track_client)
      allow(Spotify::TrackRepository).to receive(:new).with(playlist: playlist).and_return(track_repository)
      allow(track_client).to receive(:fetch_playlist_tracks).and_return(client_response)
      allow(track_repository).to receive(:process_batch).with(raw_tracks).and_return(repository_result)
    end

    it 'returns item_ids from repository' do
      result = described_class.playlist_track_batch(user: user, playlist: playlist, limit: 100, offset: 0)
      expect(result[:item_ids]).to eq([1, 2])
    end

    it 'returns counts from repository' do
      result = described_class.playlist_track_batch(user: user, playlist: playlist, limit: 100, offset: 0)
      expect(result[:counts]).to eq({ tracks_processed: 2, artists_processed: 3 })
    end

    it 'returns pagination from client' do
      result = described_class.playlist_track_batch(user: user, playlist: playlist, limit: 100, offset: 0)
      expect(result[:pagination]).to eq(client_response[:pagination])
    end

    it 'creates TrackClient for user' do
      described_class.playlist_track_batch(user: user, playlist: playlist, limit: 100, offset: 0)
      expect(Spotify::TrackClient).to have_received(:for_user).with(user)
    end

    it 'creates TrackRepository with playlist' do
      described_class.playlist_track_batch(user: user, playlist: playlist, limit: 100, offset: 0)
      expect(Spotify::TrackRepository).to have_received(:new).with(playlist: playlist)
    end

    it 'fetches tracks with correct limit and offset' do
      described_class.playlist_track_batch(user: user, playlist: playlist, limit: 50, offset: 200)
      expect(track_client).to have_received(:fetch_playlist_tracks).with(playlist, limit: 50, offset: 200)
    end
  end
end
