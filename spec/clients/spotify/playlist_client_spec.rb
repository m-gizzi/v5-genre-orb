# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::PlaylistClient do
  let(:user) { create(:user) }
  let(:client) { described_class.for_user(user) }

  describe '#fetch_user_playlists' do
    subject(:response) { client.fetch_user_playlists(limit: limit, offset: offset) }

    let(:limit) { 50 }
    let(:offset) { 0 }
    let(:base_playlist_data) do
      {
        'id' => 'playlist123',
        'name' => 'Test Playlist',
        'description' => 'Test Description',
        'public' => true,
        'collaborative' => false,
        'owner' => { 'id' => 'user123', 'display_name' => 'Test User', 'uri' => 'spotify:user:user123' },
        'snapshot_id' => 'snapshot123',
        'tracks' => { 'total' => 10 },
        'images' => [],
        'external_urls' => { 'spotify' => 'https://open.spotify.com/playlist/playlist123' },
        'uri' => 'spotify:playlist:playlist123',
        'href' => 'https://api.spotify.com/v1/playlists/playlist123'
      }
    end

    let(:raw_json_response) do
      {
        'href' => 'https://api.spotify.com/v1/users/user123/playlists?offset=0&limit=50',
        'limit' => limit,
        'next' => nil,
        'offset' => offset,
        'previous' => nil,
        'total' => 1,
        'items' => [base_playlist_data]
      }.to_json
    end

    before do
      allow(client.rspotify_user).to receive(:playlists)
        .with(limit: limit, offset: offset)
        .and_return(raw_json_response)
    end

    it 'returns a hash with items and pagination' do
      expect(response).to have_key(:items)
      expect(response).to have_key(:pagination)
    end

    it 'includes playlist hashes in the items array' do
      expect(response[:items].first).to include(
        'id' => 'playlist123',
        'name' => 'Test Playlist',
        'description' => 'Test Description'
      )
    end

    it 'includes pagination metadata' do
      expect(response[:pagination]).to eq(
        total: 1,
        limit: 50,
        offset: 0,
        next: nil,
        previous: nil
      )
    end

    context 'when no playlists exist' do
      let(:raw_json_response) do
        {
          'href' => 'https://api.spotify.com/v1/users/user123/playlists?offset=0&limit=50',
          'limit' => 50,
          'next' => nil,
          'offset' => 0,
          'previous' => nil,
          'total' => 0,
          'items' => []
        }.to_json
      end

      it 'returns empty playlists array' do
        expect(response[:items]).to eq([])
        expect(response[:pagination][:total]).to eq(0)
      end
    end
  end

  describe '#create_playlist' do
    subject(:created_playlist) { client.create_playlist(name: name, description: description, public: is_public) }

    let(:name) { 'My New Playlist' }
    let(:description) { 'A test playlist' }
    let(:is_public) { true }
    let(:new_playlist_data) do
      {
        'id' => 'new_playlist_id',
        'name' => name,
        'description' => description,
        'public' => is_public,
        'collaborative' => false,
        'owner' => { 'id' => 'user123', 'display_name' => 'Test', 'uri' => 'spotify:user:user123' },
        'snapshot_id' => 'snap_new',
        'tracks' => { 'total' => 0 },
        'images' => [],
        'external_urls' => { 'spotify' => 'https://open.spotify.com/playlist/new_playlist_id' },
        'uri' => 'spotify:playlist:new_playlist_id',
        'href' => 'https://api.spotify.com/v1/playlists/new_playlist_id'
      }
    end

    let(:raw_json_response) { new_playlist_data.to_json }

    before do
      allow(client.rspotify_user).to receive(:create_playlist!)
        .with(name, public: is_public, description: description)
        .and_return(raw_json_response)
    end

    it 'returns a playlist hash' do
      expect(created_playlist['id']).to eq('new_playlist_id')
      expect(created_playlist['name']).to eq(name)
    end
  end
end
