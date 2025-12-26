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

  describe '#spotify_api_call' do
    subject(:client) { described_class.new(user) }

    let(:endpoint) { 'spotify:playlists' }

    context 'when no cooldown is active' do
      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with(endpoint).and_return(nil)
      end

      it 'executes the block' do
        expect { |b| client.send(:spotify_api_call, endpoint, &b) }.to yield_control
      end

      it 'returns the block result' do
        result = client.send(:spotify_api_call, endpoint) { 'success' }
        expect(result).to eq('success')
      end
    end

    context 'when cooldown is active' do
      let(:cooldown) { create(:rate_limit_cooldown, :in_progress, endpoint: endpoint) }

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with(endpoint).and_return(cooldown)
      end

      it 'raises RateLimitCooldownActive error' do
        expect do
          client.send(:spotify_api_call, endpoint) { 'should not execute' }
        end.to raise_error(Spotify::Errors::RateLimitCooldownActive)
      end

      it 'does not execute the block' do
        expect do |b|
          begin
            client.send(:spotify_api_call, endpoint, &b)
          rescue Spotify::Errors::RateLimitCooldownActive
            # Expected error
          end
        end.not_to yield_control
      end

      it 'includes retry_after in error' do
        error = nil
        begin
          client.send(:spotify_api_call, endpoint) { 'should not execute' }
        rescue Spotify::Errors::RateLimitCooldownActive => e
          error = e
        end

        expect(error.retry_after).to eq(cooldown.seconds_remaining)
      end
    end

    context 'when API returns 429 Too Many Requests' do
      let(:retry_after_seconds) { 60 }
      let(:rest_client_error) do
        response = double('response', headers: { retry_after: retry_after_seconds })
        RestClient::TooManyRequests.new(response)
      end

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with(endpoint).and_return(nil)
        allow(RateLimitCooldown).to receive(:set_cooldown!)
      end

      it 'creates a cooldown record' do
        begin
          client.send(:spotify_api_call, endpoint) { raise rest_client_error }
        rescue Spotify::Errors::RateLimitError
          # Expected error
        end

        expect(RateLimitCooldown).to have_received(:set_cooldown!).with(endpoint, retry_after_seconds)
      end

      it 'raises RateLimitError with retry_after' do
        error = nil
        begin
          client.send(:spotify_api_call, endpoint) { raise rest_client_error }
        rescue Spotify::Errors::RateLimitError => e
          error = e
        end

        expect(error.retry_after).to eq(retry_after_seconds)
      end

      context 'when retry_after header is missing' do
        let(:rest_client_error) do
          response = double('response', headers: {})
          RestClient::TooManyRequests.new(response)
        end

        it 'passes nil to set_cooldown! which uses default' do
          begin
            client.send(:spotify_api_call, endpoint) { raise rest_client_error }
          rescue Spotify::Errors::RateLimitError
            # Expected error
          end

          expect(RateLimitCooldown).to have_received(:set_cooldown!).with(endpoint, nil)
        end
      end
    end

    context 'when API returns authentication error' do
      let(:auth_error) { RestClient::Unauthorized.new }

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with(endpoint).and_return(nil)
      end

      it 'raises AuthenticationError' do
        expect do
          client.send(:spotify_api_call, endpoint) { raise auth_error }
        end.to raise_error(Spotify::Errors::AuthenticationError)
      end

      it 'does not create a cooldown' do
        allow(RateLimitCooldown).to receive(:set_cooldown!)

        begin
          client.send(:spotify_api_call, endpoint) { raise auth_error }
        rescue Spotify::Errors::AuthenticationError
          # Expected error
        end

        expect(RateLimitCooldown).not_to have_received(:set_cooldown!)
      end
    end
  end
end
