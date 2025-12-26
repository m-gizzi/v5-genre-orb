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

    it 'returns a hash with playlists and pagination' do
      expect(response).to be_a(Hash)
      expect(response).to have_key(:playlists)
      expect(response).to have_key(:pagination)
    end

    it 'includes playlist hashes in the playlists array' do
      expect(response[:playlists]).to be_an(Array)
      expect(response[:playlists].first).to be_a(Hash)
      expect(response[:playlists].first).to include(
        spotify_id: 'playlist123',
        name: 'Test Playlist',
        description: 'Test Description'
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

    it 'calls rspotify_user.playlists with correct parameters' do
      response
      expect(client.rspotify_user).to have_received(:playlists).with(limit: 50, offset: 0)
    end

    context 'with custom limit and offset' do
      let(:limit) { 20 }
      let(:offset) { 40 }

      let(:raw_json_response) do
        {
          'href' => 'https://api.spotify.com/v1/users/user123/playlists?offset=40&limit=20',
          'limit' => 20,
          'next' => 'https://api.spotify.com/v1/users/user123/playlists?offset=60&limit=20',
          'offset' => 40,
          'previous' => 'https://api.spotify.com/v1/users/user123/playlists?offset=20&limit=20',
          'total' => 100,
          'items' => [base_playlist_data]
        }.to_json
      end

      it 'passes custom parameters to RSpotify' do
        response
        expect(client.rspotify_user).to have_received(:playlists).with(limit: 20, offset: 40)
      end
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
        expect(response[:playlists]).to eq([])
        expect(response[:pagination][:total]).to eq(0)
      end
    end

    context 'when API call fails' do
      before do
        allow(client.rspotify_user).to receive(:playlists).and_raise(RestClient::Unauthorized)
      end

      it 'raises AuthenticationError' do
        expect { response }.to raise_error(Spotify::Errors::AuthenticationError)
      end
    end

    context 'when rate limit cooldown is active' do
      let(:cooldown) { create(:rate_limit_cooldown, :in_progress, endpoint: 'spotify:users:playlists') }

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with('spotify:users:playlists').and_return(cooldown)
      end

      it 'raises RateLimitCooldownActive without calling API' do
        expect { response }.to raise_error(Spotify::Errors::RateLimitCooldownActive)
        expect(client.rspotify_user).not_to have_received(:playlists)
      end
    end

    context 'when API returns 429 Too Many Requests' do
      let(:retry_after) { 60 }
      let(:too_many_requests_error) do
        response = double('response', headers: { retry_after: retry_after })
        RestClient::TooManyRequests.new(response)
      end

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).and_return(nil)
        allow(RateLimitCooldown).to receive(:set_cooldown!)
        allow(client.rspotify_user).to receive(:playlists).and_raise(too_many_requests_error)
      end

      it 'creates a rate limit cooldown' do
        begin
          response
        rescue Spotify::Errors::RateLimitError
          # Expected error
        end

        expect(RateLimitCooldown).to have_received(:set_cooldown!).with('spotify:users:playlists', retry_after)
      end

      it 'raises RateLimitError' do
        expect { response }.to raise_error(Spotify::Errors::RateLimitError)
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
      expect(created_playlist).to be_a(Hash)
      expect(created_playlist[:spotify_id]).to eq('new_playlist_id')
      expect(created_playlist[:name]).to eq(name)
    end

    it 'calls create_playlist! on rspotify_user' do
      created_playlist
      expect(client.rspotify_user).to have_received(:create_playlist!)
        .with(name, public: is_public, description: description)
    end

    context 'with minimal parameters' do
      subject(:created_playlist) { client.create_playlist(name: name) }

      before do
        allow(client.rspotify_user).to receive(:create_playlist!)
          .with(name, public: true, description: nil)
          .and_return(raw_json_response)
      end

      it 'uses default values for public and description' do
        created_playlist
        expect(client.rspotify_user).to have_received(:create_playlist!)
          .with(name, public: true, description: nil)
      end
    end

    context 'when creating a private playlist' do
      let(:is_public) { false }

      it 'passes public: false to RSpotify' do
        created_playlist
        expect(client.rspotify_user).to have_received(:create_playlist!)
          .with(name, public: false, description: description)
      end
    end

    context 'when API call fails' do
      before do
        allow(client.rspotify_user).to receive(:create_playlist!).and_raise(RestClient::BadRequest)
      end

      it 'raises ApiError' do
        expect { created_playlist }.to raise_error(Spotify::Errors::ApiError)
      end
    end

    context 'when rate limit cooldown is active' do
      let(:cooldown) { create(:rate_limit_cooldown, :in_progress, endpoint: 'spotify:users:create_playlist') }

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with('spotify:users:create_playlist').and_return(cooldown)
      end

      it 'raises RateLimitCooldownActive without calling API' do
        expect { created_playlist }.to raise_error(Spotify::Errors::RateLimitCooldownActive)
        expect(client.rspotify_user).not_to have_received(:create_playlist!)
      end
    end

    context 'when API returns 429 Too Many Requests' do
      let(:retry_after) { 120 }
      let(:too_many_requests_error) do
        response = double('response', headers: { retry_after: retry_after })
        RestClient::TooManyRequests.new(response)
      end

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).and_return(nil)
        allow(RateLimitCooldown).to receive(:set_cooldown!)
        allow(client.rspotify_user).to receive(:create_playlist!).and_raise(too_many_requests_error)
      end

      it 'creates a rate limit cooldown' do
        begin
          created_playlist
        rescue Spotify::Errors::RateLimitError
          # Expected error
        end

        expect(RateLimitCooldown).to have_received(:set_cooldown!).with('spotify:users:create_playlist', retry_after)
      end

      it 'raises RateLimitError' do
        expect { created_playlist }.to raise_error(Spotify::Errors::RateLimitError)
      end
    end
  end
end
