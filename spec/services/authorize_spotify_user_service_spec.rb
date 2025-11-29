# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthorizeSpotifyUserService do
  describe '#call' do
    let(:auth_hash) do
      {
        'uid' => 'spotify123',
        'info' => {
          'email' => 'test@example.com',
          'display_name' => 'Test User'
        },
        'credentials' => {
          'token' => 'access_token_123',
          'refresh_token' => 'refresh_token_123',
          'expires_at' => 1.hour.from_now.to_i
        }
      }
    end

    context 'when user does not exist' do
      it 'creates a new user' do
        expect { described_class.call(auth_hash) }.to change(User, :count).by(1)
      end

      it 'sets correct user attributes' do
        user = described_class.call(auth_hash)
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
        expect { described_class.call(auth_hash) }.not_to change(User, :count)
      end

      it 'updates existing user tokens' do
        user = described_class.call(auth_hash)
        expect(user.id).to eq(existing_user.id)
        expect(user.access_token).to eq('access_token_123')
        expect(user.refresh_token).to eq('refresh_token_123')
      end
    end

    context 'when display_name is missing' do
      before do
        auth_hash['info']['display_name'] = nil
      end

      it 'uses email prefix as display name' do
        user = described_class.call(auth_hash)
        expect(user.spotify_display_name).to eq('test')
      end
    end
  end
end
