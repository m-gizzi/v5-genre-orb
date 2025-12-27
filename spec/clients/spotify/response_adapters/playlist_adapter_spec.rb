# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::ResponseAdapters::PlaylistAdapter do
  describe '.adapt' do
    subject(:adapted_playlist) { described_class.adapt(playlist_data) }

    let(:owner_data) do
      {
        'id' => 'owner123',
        'display_name' => 'Test Owner',
        'uri' => 'spotify:user:owner123'
      }
    end

    let(:base_playlist_data) do
      {
        'id' => 'playlist123',
        'name' => 'Test Playlist',
        'description' => 'A test playlist',
        'public' => true,
        'collaborative' => false,
        'owner' => owner_data,
        'snapshot_id' => 'snapshot123',
        'tracks' => { 'total' => 42 },
        'images' => [
          { 'url' => 'https://example.com/image1.jpg', 'height' => 640, 'width' => 640 },
          { 'url' => 'https://example.com/image2.jpg', 'height' => 300, 'width' => 300 }
        ],
        'external_urls' => { 'spotify' => 'https://open.spotify.com/playlist/playlist123' },
        'uri' => 'spotify:playlist:playlist123',
        'href' => 'https://api.spotify.com/v1/playlists/playlist123'
      }
    end

    let(:playlist_data) { base_playlist_data }

    it 'includes all essential playlist metadata' do
      expect(adapted_playlist).to include(
        spotify_id: 'playlist123',
        name: 'Test Playlist',
        description: 'A test playlist',
        public: true,
        collaborative: false,
        snapshot_id: 'snapshot123',
        tracks_total: 42,
        uri: 'spotify:playlist:playlist123',
        href: 'https://api.spotify.com/v1/playlists/playlist123'
      )
    end

    it 'transforms owner data' do
      expect(adapted_playlist[:owner]).to eq(
        id: 'owner123',
        display_name: 'Test Owner',
        uri: 'spotify:user:owner123'
      )
    end

    it 'transforms images data' do
      expect(adapted_playlist[:images]).to eq([
        { url: 'https://example.com/image1.jpg', height: 640, width: 640 },
        { url: 'https://example.com/image2.jpg', height: 300, width: 300 }
      ])
    end

    it 'includes external URLs' do
      expect(adapted_playlist[:external_urls]).to eq(
        'spotify' => 'https://open.spotify.com/playlist/playlist123'
      )
    end
  end
end
