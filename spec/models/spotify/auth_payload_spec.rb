# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::AuthPayload do
  describe '.from_auth_hash' do
    subject(:payload) { described_class.from_auth_hash(auth_hash) }

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

    it 'extracts spotify_id (uid) from top level' do
      expect(payload.spotify_id).to eq('spotify123')
    end

    it 'extracts email from info hash' do
      expect(payload.email).to eq('test@example.com')
    end

    it 'extracts display_name from info hash' do
      expect(payload.display_name).to eq('Test User')
    end

    it 'extracts token from credentials hash' do
      expect(payload.token).to eq('access_token_123')
    end

    it 'extracts refresh_token from credentials hash' do
      expect(payload.refresh_token).to eq('refresh_token_123')
    end

    it 'extracts expires_at from credentials hash' do
      expect(payload.expires_at).to be_present
    end

    context 'with missing nested keys' do
      it 'handles missing info hash gracefully' do
        auth_hash.delete('info')
        expect(payload.email).to be_nil
        expect(payload.display_name).to be_nil
      end

      it 'handles missing credentials hash gracefully' do
        auth_hash.delete('credentials')
        expect(payload.token).to be_nil
        expect(payload.refresh_token).to be_nil
        expect(payload.expires_at).to be_nil
      end

      it 'handles missing display_name gracefully' do
        auth_hash['info'].delete('display_name')
        expect(payload.display_name).to be_nil
      end
    end
  end

  describe 'validations' do
    subject(:payload) { described_class.new(attributes) }

    let(:valid_attributes) do
      {
        spotify_id: 'spotify123',
        email: 'test@example.com',
        display_name: 'Test User',
        token: 'access_token_123',
        refresh_token: 'refresh_token_123',
        expires_at: 1.hour.from_now.to_i
      }
    end
    let(:attributes) { valid_attributes }

    it 'is valid with all required attributes' do
      expect(payload).to be_valid
    end

    describe 'spotify_id' do
      let(:attributes) { valid_attributes.merge(spotify_id: nil) }

      it 'is required' do
        expect(payload).not_to be_valid
        expect(payload.errors[:spotify_id]).to include("can't be blank")
      end
    end

    describe 'email' do
      let(:attributes) { valid_attributes.merge(email: nil) }

      it 'is required' do
        expect(payload).not_to be_valid
        expect(payload.errors[:email]).to include("can't be blank")
      end
    end

    describe 'display_name' do
      let(:attributes) { valid_attributes.merge(display_name: nil) }

      it 'is optional' do
        expect(payload).to be_valid
      end
    end

    describe 'token' do
      let(:attributes) { valid_attributes.merge(token: nil) }

      it 'is required' do
        expect(payload).not_to be_valid
        expect(payload.errors[:token]).to include("can't be blank")
      end
    end

    describe 'refresh_token' do
      let(:attributes) { valid_attributes.merge(refresh_token: nil) }

      it 'is required' do
        expect(payload).not_to be_valid
        expect(payload.errors[:refresh_token]).to include("can't be blank")
      end
    end

    describe 'expires_at' do
      let(:attributes) { valid_attributes.merge(expires_at: nil) }

      it 'is required' do
        expect(payload).not_to be_valid
        expect(payload.errors[:expires_at]).to include("can't be blank")
      end
    end
  end

  describe '#to_user_attributes' do
    let(:payload) do
      described_class.new(
        spotify_id: 'spotify123',
        email: 'test@example.com',
        display_name: 'Test User',
        token: 'access_token_123',
        refresh_token: 'refresh_token_123',
        expires_at: 1_234_567_890
      )
    end

    it 'returns a hash with User model attribute names' do
      attributes = payload.to_user_attributes
      expect(attributes.keys).to contain_exactly(
        :spotify_id,
        :spotify_email,
        :spotify_display_name,
        :access_token,
        :refresh_token,
        :token_expires_at
      )
    end

    it 'maps email to spotify_email' do
      expect(payload.to_user_attributes[:spotify_email]).to eq('test@example.com')
    end

    it 'maps display_name to spotify_display_name' do
      expect(payload.to_user_attributes[:spotify_display_name]).to eq('Test User')
    end

    it 'maps token to access_token' do
      expect(payload.to_user_attributes[:access_token]).to eq('access_token_123')
    end

    it 'maps refresh_token directly' do
      expect(payload.to_user_attributes[:refresh_token]).to eq('refresh_token_123')
    end

    it 'converts expires_at to Time object' do
      time = payload.to_user_attributes[:token_expires_at]
      expect(time).to be_a(Time)
      expect(time.to_i).to eq(1_234_567_890)
    end
  end

  describe '#spotify_id' do
    it 'returns the spotify_id attribute' do
      payload = described_class.new(spotify_id: 'spotify123')
      expect(payload.spotify_id).to eq('spotify123')
    end
  end

  describe '#computed_display_name' do
    context 'when display_name is present' do
      it 'returns the display_name' do
        payload = described_class.new(
          email: 'test@example.com',
          display_name: 'Test User'
        )
        expect(payload.computed_display_name).to eq('Test User')
      end
    end

    context 'when display_name is nil' do
      it 'returns email prefix (part before @)' do
        payload = described_class.new(
          email: 'test@example.com',
          display_name: nil
        )
        expect(payload.computed_display_name).to eq('test')
      end
    end

    context 'when display_name is empty string' do
      it 'returns email prefix (part before @)' do
        payload = described_class.new(
          email: 'test@example.com',
          display_name: ''
        )
        expect(payload.computed_display_name).to eq('test')
      end
    end

    context 'when email is nil' do
      it 'returns nil gracefully' do
        payload = described_class.new(
          email: nil,
          display_name: nil
        )
        expect(payload.computed_display_name).to be_nil
      end
    end
  end

  describe '#token_expires_at_time' do
    it 'converts Unix timestamp to Time object' do
      payload = described_class.new(expires_at: 1_234_567_890)
      time = payload.token_expires_at_time
      expect(time).to be_a(Time)
      expect(time.to_i).to eq(1_234_567_890)
    end
  end
end
