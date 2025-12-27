# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::BaseClient do
  let(:user) { create(:user) }

  describe '#handle_spotify_errors' do
    subject(:client) { described_class.new(user) }

    let(:endpoint) { 'spotify:playlists' }

    context 'when no cooldown is active' do
      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with(endpoint).and_return(nil)
      end

      it 'returns the block result' do
        result = client.send(:handle_spotify_errors, endpoint) { 'success' }
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
          client.send(:handle_spotify_errors, endpoint) { 'should not execute' }
        end.to raise_error(Spotify::Errors::RateLimitCooldownActive)
      end

      it 'includes retry_after in error' do
        error = nil
        begin
          client.send(:handle_spotify_errors, endpoint) { 'should not execute' }
        rescue Spotify::Errors::RateLimitCooldownActive => e
          error = e
        end

        expect(error.retry_after).to eq(cooldown.seconds_remaining)
      end
    end

    context 'when API returns 429 Too Many Requests' do
      let(:retry_after_seconds) { 60 }
      let(:rest_client_error) do
        response = instance_double(RestClient::Response, headers: { retry_after: retry_after_seconds })
        RestClient::TooManyRequests.new(response)
      end

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with(endpoint).and_return(nil)
        allow(RateLimitCooldown).to receive(:set_cooldown!)
      end

      it 'creates a cooldown record' do
        begin
          client.send(:handle_spotify_errors, endpoint) { raise rest_client_error }
        rescue Spotify::Errors::RateLimitError
          # Expected error
        end

        expect(RateLimitCooldown).to have_received(:set_cooldown!).with(endpoint, retry_after_seconds)
      end

      it 'raises RateLimitError with retry_after' do
        error = nil
        begin
          client.send(:handle_spotify_errors, endpoint) { raise rest_client_error }
        rescue Spotify::Errors::RateLimitError => e
          error = e
        end

        expect(error.retry_after).to eq(retry_after_seconds)
      end
    end

    context 'when API returns authentication error' do
      let(:auth_error) { RestClient::Unauthorized.new }

      before do
        allow(RateLimitCooldown).to receive(:find_in_progress).with(endpoint).and_return(nil)
      end

      it 'raises AuthenticationError' do
        expect do
          client.send(:handle_spotify_errors, endpoint) { raise auth_error }
        end.to raise_error(Spotify::Errors::AuthenticationError)
      end
    end
  end
end
