# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateSpotifyPlaylistService do
  describe '#call' do
    subject(:create_playlist) do
      described_class.call(user, name: name, description: description, public: is_public)
    end

    let(:user) { create(:user) }
    let(:name) { 'My New Playlist' }
    let(:description) { 'A great playlist' }
    let(:is_public) { true }
    let(:spotify_client) { instance_double(Spotify::PlaylistClient) }
    let(:spotify_playlist_data) do
      {
        spotify_id: 'new_spotify_id',
        name: name,
        description: description,
        public: is_public,
        collaborative: false,
        owner: { id: user.spotify_id, display_name: user.spotify_display_name },
        snapshot_id: 'snapshot123',
        tracks_total: 0
      }
    end

    before do
      allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(spotify_client)
      allow(spotify_client).to receive(:create_playlist)
        .with(name: name, description: description, public: is_public)
        .and_return(spotify_playlist_data)
    end

    it 'creates a playlist on Spotify' do
      create_playlist
      expect(spotify_client).to have_received(:create_playlist)
        .with(name: name, description: description, public: is_public)
    end

    it 'creates a local playlist record' do
      expect { create_playlist }.to change(user.playlists, :count).by(1)
    end

    it 'returns the created playlist' do
      result = create_playlist
      expect(result).to be_a(Playlist)
      expect(result.spotify_id).to eq('new_spotify_id')
      expect(result.name).to eq(name)
    end

    it 'stores the playlist data correctly' do
      playlist = create_playlist

      expect(playlist.name).to eq(name)
      expect(playlist.description).to eq(description)
      expect(playlist.spotify_id).to eq('new_spotify_id')
      expect(playlist.raw_data).to eq(spotify_playlist_data.with_indifferent_access)
    end

    it 'associates the playlist with the user' do
      playlist = create_playlist
      expect(playlist.user).to eq(user)
    end

    context 'with minimal parameters' do
      subject(:create_playlist) { described_class.call(user, name: name) }

      before do
        allow(spotify_client).to receive(:create_playlist)
          .with(name: name, description: nil, public: true)
          .and_return(spotify_playlist_data)
      end

      it 'uses default values for optional parameters' do
        create_playlist
        expect(spotify_client).to have_received(:create_playlist)
          .with(name: name, description: nil, public: true)
      end
    end

    context 'when creating a private playlist' do
      let(:is_public) { false }

      it 'creates a private playlist on Spotify' do
        create_playlist
        expect(spotify_client).to have_received(:create_playlist)
          .with(name: name, description: description, public: false)
      end
    end

    context 'when Spotify API call fails' do
      before do
        allow(spotify_client).to receive(:create_playlist)
          .and_raise(Spotify::Errors::ApiError, 'Spotify error')
      end

      it 'raises the Spotify error' do
        expect { create_playlist }.to raise_error(Spotify::Errors::ApiError)
      end

      it 'does not create a local playlist' do
        expect do
          create_playlist
        rescue Spotify::Errors::ApiError
          # Expected
        end.not_to change(Playlist, :count)
      end
    end

    context 'when playlist with same spotify_id already exists' do
      let!(:existing_playlist) { create(:playlist, user: user, spotify_id: 'new_spotify_id') }

      it 'raises a validation error' do
        expect { create_playlist }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
