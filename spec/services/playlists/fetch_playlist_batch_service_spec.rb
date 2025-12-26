# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Playlists::FetchPlaylistBatchService do
  let(:user) { create(:user) }
  let(:sync_run) { create(:playlist_sync_run, user: user) }
  let(:spotify_client) { instance_double(Spotify::PlaylistClient) }
  let(:service) { described_class.new(sync_run: sync_run, offset: 50, limit: 50) }

  before do
    allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(spotify_client)
  end

  let(:playlists) do
    Array.new(50) do |i|
      {
        spotify_id: "playlist#{i + 50}",
        name: "Playlist #{i + 50}",
        description: "Description #{i + 50}",
        raw_data: { 'id' => "playlist#{i + 50}" }
      }
    end
  end

  let(:response) do
    {
      playlists: playlists,
      pagination: {
        total: 150,
        limit: 50,
        offset: 50,
        next: 'https://api.spotify.com/v1/users/user123/playlists?offset=100&limit=50',
        previous: 'https://api.spotify.com/v1/users/user123/playlists?offset=0&limit=50'
      }
    }
  end

  before do
    allow(spotify_client).to receive(:fetch_user_playlists)
      .with(limit: 50, offset: 50).and_return(response)
  end

  it 'fetches playlists from Spotify' do
    service.call
    expect(spotify_client).to have_received(:fetch_user_playlists)
      .with(limit: 50, offset: 50)
  end

  it 'processes the batch' do
    expect { service.call }.to change { user.playlists.count }.by(50)
  end

  it 'marks batch as complete' do
    expect { service.call }
      .to change { sync_run.reload.batches_completed }.by(1)
  end

  it 'increments playlists_processed counter' do
    service.call
    expect(sync_run.reload.playlists_processed).to eq(50)
  end

  context 'with custom limit' do
    let(:service) { described_class.new(sync_run: sync_run, offset: 0, limit: 20) }

    let(:response) do
      {
        playlists: playlists.take(20),
        pagination: {
          total: 100,
          limit: 20,
          offset: 0,
          next: 'https://api.spotify.com/v1/users/user123/playlists?offset=20&limit=20',
          previous: nil
        }
      }
    end

    before do
      allow(spotify_client).to receive(:fetch_user_playlists)
        .with(limit: 20, offset: 0).and_return(response)
    end

    it 'passes custom limit to Spotify client' do
      service.call
      expect(spotify_client).to have_received(:fetch_user_playlists)
        .with(limit: 20, offset: 0)
    end
  end
end
