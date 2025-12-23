# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthorizeSpotifyUserService do
  describe '#call' do
    let(:auth_payload) do
      Spotify::AuthPayload.new(
        spotify_id: 'spotify123',
        email: 'test@example.com',
        display_name: 'Test User',
        token: 'access_token_123',
        refresh_token: 'refresh_token_123',
        expires_at: 1.hour.from_now.to_i
      )
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect { described_class.call(auth_payload) }.to change(User, :count).by(1)
      end

      it 'sets correct user attributes' do
        user = described_class.call(auth_payload)
        expect(user.spotify_id).to eq('spotify123')
        expect(user.spotify_email).to eq('test@example.com')
        expect(user.spotify_display_name).to eq('Test User')
        expect(user.access_token).to eq('access_token_123')
        expect(user.refresh_token).to eq('refresh_token_123')
        expect(user.token_expires_at).to be_present
      end
    end

    context 'when user already exists' do
      let!(:existing_user) do
        create(:user,
               spotify_id: 'spotify123',
               access_token: 'old_token',
               refresh_token: 'old_refresh')
      end

      it 'does not create a new user' do
        expect { described_class.call(auth_payload) }.not_to change(User, :count)
      end

      it 'updates existing user tokens' do
        user = described_class.call(auth_payload)
        expect(user.id).to eq(existing_user.id)
        expect(user.access_token).to eq('access_token_123')
        expect(user.refresh_token).to eq('refresh_token_123')
      end
    end
  end
end
