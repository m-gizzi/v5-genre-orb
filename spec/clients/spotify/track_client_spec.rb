# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::TrackClient do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user) }
  let(:client) { described_class.for_user(user) }
  let(:rspotify_playlist) { instance_double(RSpotify::Playlist) }

  describe '#fetch_playlist_tracks' do
    subject(:response) { client.fetch_playlist_tracks(playlist, limit: limit, offset: offset) }

    let(:limit) { 100 }
    let(:offset) { 0 }
    let(:base_track_data) do
      {
        'track' => {
          'id' => 'track123',
          'name' => 'Test Track',
          'duration_ms' => 180_000,
          'disc_number' => 1,
          'track_number' => 1,
          'explicit' => false,
          'is_local' => false,
          'popularity' => 75,
          'preview_url' => 'https://p.scdn.co/mp3-preview/test',
          'external_ids' => { 'isrc' => 'USUM71234567' },
          'artists' => [
            { 'id' => 'artist123', 'name' => 'Test Artist' }
          ],
          'album' => {
            'name' => 'Test Album',
            'images' => [{ 'url' => 'https://i.scdn.co/image/test', 'height' => 640, 'width' => 640 }]
          },
          'external_urls' => { 'spotify' => 'https://open.spotify.com/track/track123' },
          'uri' => 'spotify:track:track123',
          'href' => 'https://api.spotify.com/v1/tracks/track123'
        },
        'added_at' => '2024-01-01T12:00:00Z',
        'added_by' => { 'id' => 'user123' }
      }
    end

    let(:raw_json_response) do
      {
        'href' => 'https://api.spotify.com/v1/playlists/playlist123/tracks?offset=0&limit=100',
        'limit' => limit,
        'next' => nil,
        'offset' => offset,
        'previous' => nil,
        'total' => 1,
        'items' => [base_track_data]
      }.to_json
    end

    before do
      allow(Spotify::RspotifyBuilder).to receive(:build_playlist)
        .with(playlist).and_return(rspotify_playlist)
      allow(rspotify_playlist).to receive(:tracks)
        .with(limit: limit, offset: offset)
        .and_return(raw_json_response)
    end

    it 'returns a hash with items and pagination' do
      expect(response).to have_key(:items)
      expect(response).to have_key(:pagination)
    end

    it 'includes track hashes in the items array' do
      expect(response[:items].first).to include(
        'track' => hash_including(
          'id' => 'track123',
          'name' => 'Test Track'
        )
      )
    end

    it 'includes pagination metadata' do
      expect(response[:pagination]).to eq(
        total: 1,
        limit: 100,
        offset: 0,
        next: nil,
        previous: nil
      )
    end

    it 'uses RspotifyBuilder to build playlist' do
      response
      expect(Spotify::RspotifyBuilder).to have_received(:build_playlist).with(playlist)
    end

    context 'when playlist has no tracks' do
      let(:raw_json_response) do
        {
          'href' => 'https://api.spotify.com/v1/playlists/playlist123/tracks?offset=0&limit=100',
          'limit' => 100,
          'next' => nil,
          'offset' => 0,
          'previous' => nil,
          'total' => 0,
          'items' => []
        }.to_json
      end

      it 'returns empty tracks array' do
        expect(response[:items]).to eq([])
        expect(response[:pagination][:total]).to eq(0)
      end
    end

    context 'when there are multiple pages' do
      let(:raw_json_response) do
        {
          'href' => 'https://api.spotify.com/v1/playlists/playlist123/tracks?offset=0&limit=100',
          'limit' => 100,
          'next' => 'https://api.spotify.com/v1/playlists/playlist123/tracks?offset=100&limit=100',
          'offset' => 0,
          'previous' => nil,
          'total' => 250,
          'items' => [base_track_data]
        }.to_json
      end

      it 'includes next page URL in pagination' do
        expect(response[:pagination][:next]).to eq('https://api.spotify.com/v1/playlists/playlist123/tracks?offset=100&limit=100')
        expect(response[:pagination][:total]).to eq(250)
      end
    end
  end
end
