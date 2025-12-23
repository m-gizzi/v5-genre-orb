# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::BaseClient do
  let(:user) { create(:user) }

  describe '.for_user' do
    subject(:client) { described_class.for_user(user) }

    it 'returns a BaseClient instance' do
      expect(client).to be_a(described_class)
    end

    it 'initializes with the user' do
      expect(client.user).to eq(user)
    end
  end

  describe '#initialize' do
    subject(:client) { described_class.new(user) }

    it 'builds an RSpotify::User instance' do
      expect(client.rspotify_user).to be_a(RSpotify::User)
    end

    it 'configures RSpotify::User with correct credentials' do
      rspotify_credentials = client.rspotify_user.credentials

      expect(rspotify_credentials['token']).to eq(user.access_token)
      expect(rspotify_credentials['refresh_token']).to eq(user.refresh_token)
      expect(rspotify_credentials['access_refresh_callback']).to be_a(Proc)
    end

    it 'sets the correct Spotify user ID' do
      expect(client.rspotify_user.id).to eq(user.spotify_id)
    end
  end
end
