# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::RspotifyBuilder do
  describe '.build_user' do
    let(:user) { create(:user) }
    let(:rspotify_user) { described_class.build_user(user) }

    it 'returns an RSpotify::User instance' do
      expect(rspotify_user).to be_a(RSpotify::User)
    end

    it 'sets the user id' do
      expect(rspotify_user.id).to eq(user.spotify_id)
    end

    it 'includes access token in credentials' do
      credentials = rspotify_user.instance_variable_get(:@credentials)
      expect(credentials['token']).to eq(user.access_token)
    end

    it 'includes refresh token in credentials' do
      credentials = rspotify_user.instance_variable_get(:@credentials)
      expect(credentials['refresh_token']).to eq(user.refresh_token)
    end

    it 'includes access_refresh_callback in credentials' do
      credentials = rspotify_user.instance_variable_get(:@credentials)
      expect(credentials['access_refresh_callback']).to be_a(Proc)
    end

    context 'when token refresh callback is invoked' do
      it 'updates user credentials' do
        credentials = rspotify_user.instance_variable_get(:@credentials)
        callback = credentials['access_refresh_callback']

        expect(user).to receive(:update_spotify_credentials).with('new_token', 3600)
        callback.call('new_token', 3600)
      end

      it 'raises AuthenticationError when update fails' do
        credentials = rspotify_user.instance_variable_get(:@credentials)
        callback = credentials['access_refresh_callback']

        allow(user).to receive(:update_spotify_credentials).and_raise(StandardError.new('DB error'))

        expect do
          callback.call('new_token', 3600)
        end.to raise_error(Spotify::Errors::AuthenticationError, /Failed to persist refreshed token/)
      end
    end
  end

  describe '.build_playlist' do
    let(:playlist) { create(:playlist) }
    let(:rspotify_playlist) { described_class.build_playlist(playlist) }

    it 'returns an RSpotify::Playlist instance' do
      expect(rspotify_playlist).to be_a(RSpotify::Playlist)
    end

    it 'uses playlist raw_data to build RSpotify object' do
      expect(rspotify_playlist.id).to eq(playlist.spotify_id)
      expect(rspotify_playlist.name).to eq(playlist.name)
    end

    it 'stringifies keys from raw_data' do
      # RSpotify expects string keys
      expect(playlist.raw_data.keys.first).to be_a(Symbol).or be_a(String)
    end
  end
end
