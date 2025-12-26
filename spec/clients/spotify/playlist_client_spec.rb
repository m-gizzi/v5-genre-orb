# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::PlaylistClient do
  let(:user) { create(:user) }
  let(:client) { described_class.for_user(user) }

  describe '#fetch_user_playlists' do
    subject(:playlists) { client.fetch_user_playlists(limit: limit, offset: offset) }

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
    let(:rspotify_playlist) { RSpotify::Playlist.new(base_playlist_data) }

    before do
      allow(client.rspotify_user).to receive(:playlists)
        .with(limit: limit, offset: offset)
        .and_return([rspotify_playlist])
    end

    it 'returns an array of playlist hashes' do
      expect(playlists).to be_an(Array)
      expect(playlists.first).to be_a(Hash)
    end

    it 'uses PlaylistAdapter to transform playlists' do
      expect(playlists.first).to include(
        spotify_id: 'playlist123',
        name: 'Test Playlist',
        description: 'Test Description'
      )
    end

    it 'calls rspotify_user.playlists with correct parameters' do
      playlists
      expect(client.rspotify_user).to have_received(:playlists).with(limit: 50, offset: 0)
    end

    context 'with custom limit and offset' do
      let(:limit) { 20 }
      let(:offset) { 40 }

      it 'passes custom parameters to RSpotify' do
        playlists
        expect(client.rspotify_user).to have_received(:playlists).with(limit: 20, offset: 40)
      end
    end

    context 'when no playlists exist' do
      before do
        allow(client.rspotify_user).to receive(:playlists).and_return([])
      end

      it 'returns an empty array' do
        expect(playlists).to eq([])
      end
    end

    context 'when API call fails' do
      before do
        allow(client.rspotify_user).to receive(:playlists).and_raise(RestClient::Unauthorized)
      end

      it 'raises AuthenticationError' do
        expect { playlists }.to raise_error(Spotify::Errors::AuthenticationError)
      end
    end

    context 'when rate limit cooldown is active' do
      let(:cooldown) { create(:rate_limit_cooldown, :in_progress, endpoint: 'spotify:users:playlists') }

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with('spotify:users:playlists').and_return(cooldown)
      end

      it 'raises RateLimitCooldownActive without calling API' do
        expect { playlists }.to raise_error(Spotify::Errors::RateLimitCooldownActive)
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
          playlists
        rescue Spotify::Errors::RateLimitError
          # Expected error
        end

        expect(RateLimitCooldown).to have_received(:set_cooldown!).with('spotify:users:playlists', retry_after)
      end

      it 'raises RateLimitError' do
        expect { playlists }.to raise_error(Spotify::Errors::RateLimitError)
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
    let(:rspotify_playlist) { RSpotify::Playlist.new(new_playlist_data) }

    before do
      allow(client.rspotify_user).to receive(:create_playlist!)
        .with(name, public: is_public, description: description)
        .and_return(rspotify_playlist)
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
          .and_return(rspotify_playlist)
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
