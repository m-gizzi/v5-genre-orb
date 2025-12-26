# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Playlists::CoordinatorJob do
  let(:user) { create(:user) }
  let(:sync_run) { create(:playlist_sync_run, user: user, status: :pending) }
  let(:spotify_client) { instance_double(Spotify::PlaylistClient) }

  before do
    allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(spotify_client)
  end

  describe '#perform' do
    context 'when user has fewer than 50 playlists' do
      let(:playlists) do
        Array.new(25) do |i|
          { spotify_id: "playlist#{i}", name: "Playlist #{i}", description: nil, raw_data: {} }
        end
      end

      let(:response) do
        {
          playlists: playlists,
          pagination: {
            total: 25,
            limit: 50,
            offset: 0,
            next: nil,
            previous: nil
          }
        }
      end

      before do
        allow(spotify_client).to receive(:fetch_user_playlists).with(limit: 50, offset: 0).and_return(response)
      end

      it 'transitions to fetching_metadata status' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload.status).to eq('processing_batches')
      end

      it 'sets started_at timestamp' do
        freeze_time do
          described_class.perform_now(sync_run.id)
          expect(sync_run.reload.started_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'sets total_playlists_expected from pagination metadata' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload.total_playlists_expected).to eq(25)
      end

      it 'sets batches_total to 1' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload.batches_total).to eq(1)
      end

      it 'enqueues one FetchBatchJob' do
        expect do
          described_class.perform_now(sync_run.id)
        end.to have_enqueued_job(Playlists::FetchBatchJob).exactly(1).times
      end

      it 'enqueues FetchBatchJob with correct parameters' do
        described_class.perform_now(sync_run.id)
        expect(Playlists::FetchBatchJob).to have_been_enqueued.with(sync_run.id, 0, 50)
      end
    end

    context 'when user has exactly 50 playlists' do
      let(:playlists) do
        Array.new(50) do |i|
          { spotify_id: "playlist#{i}", name: "Playlist #{i}", description: nil, raw_data: {} }
        end
      end

      let(:response) do
        {
          playlists: playlists,
          pagination: {
            total: 50,
            limit: 50,
            offset: 0,
            next: nil,
            previous: nil
          }
        }
      end

      before do
        allow(spotify_client).to receive(:fetch_user_playlists).with(limit: 50, offset: 0).and_return(response)
      end

      it 'sets total_playlists_expected to 50 (accurate from API)' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload.total_playlists_expected).to eq(50)
      end

      it 'sets batches_total to 1 (accurate from API)' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload.batches_total).to eq(1)
      end

      it 'enqueues one FetchBatchJob' do
        expect do
          described_class.perform_now(sync_run.id)
        end.to have_enqueued_job(Playlists::FetchBatchJob).exactly(1).times
      end
    end

    context 'when user has 0 playlists' do
      let(:response) do
        {
          playlists: [],
          pagination: {
            total: 0,
            limit: 50,
            offset: 0,
            next: nil,
            previous: nil
          }
        }
      end

      before do
        allow(spotify_client).to receive(:fetch_user_playlists).with(limit: 50, offset: 0).and_return(response)
      end

      it 'sets total_playlists_expected to 0' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload.total_playlists_expected).to eq(0)
      end

      it 'sets batches_total to 1' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload.batches_total).to eq(1)
      end

      it 'still enqueues one FetchBatchJob' do
        expect do
          described_class.perform_now(sync_run.id)
        end.to have_enqueued_job(Playlists::FetchBatchJob).exactly(1).times
      end

      it 'transitions to processing_batches' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload).to be_processing_batches
      end
    end

    context 'when sync_run is already processing' do
      let(:sync_run) { create(:playlist_sync_run, user: user, status: :processing_batches) }
      let(:playlists) do
        Array.new(10) do |i|
          { spotify_id: "playlist#{i}", name: "Playlist #{i}", description: nil, raw_data: {} }
        end
      end

      let(:response) do
        {
          playlists: playlists,
          pagination: {
            total: 10,
            limit: 50,
            offset: 0,
            next: nil,
            previous: nil
          }
        }
      end

      before do
        allow(spotify_client).to receive(:fetch_user_playlists).with(limit: 50, offset: 0).and_return(response)
      end

      it 'still fetches and processes' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload.batches_total).to eq(1)
      end
    end

    context 'when rate limit cooldown is active' do
      before do
        allow(spotify_client).to receive(:fetch_user_playlists)
          .and_raise(Spotify::Errors::RateLimitCooldownActive.new('Rate limited', retry_after: 60))
      end

      it 'does not update sync_run totals' do
        job = described_class.new(sync_run.id)
        begin
          job.send(:perform, sync_run.id)
        rescue Spotify::Errors::RateLimitCooldownActive
          # Expected - handled by SpotifyJobErrorHandling
        end

        expect(sync_run.reload.batches_total).to eq(0)
      end

      it 'does not enqueue any batch jobs' do
        job = described_class.new(sync_run.id)
        expect do
          begin
            job.send(:perform, sync_run.id)
          rescue Spotify::Errors::RateLimitCooldownActive
            # Expected
          end
        end.not_to have_enqueued_job(Playlists::FetchBatchJob)
      end
    end

    context 'when Spotify returns rate limit error' do
      before do
        allow(spotify_client).to receive(:fetch_user_playlists)
          .and_raise(Spotify::Errors::RateLimitError.new('Rate limit exceeded', retry_after: 120))
      end

      it 'does not update sync_run totals' do
        job = described_class.new(sync_run.id)
        begin
          job.send(:perform, sync_run.id)
        rescue Spotify::Errors::RateLimitError
          # Expected
          end

        expect(sync_run.reload.batches_total).to eq(0)
      end

      it 'does not enqueue any batch jobs' do
        job = described_class.new(sync_run.id)
        expect do
          begin
            job.send(:perform, sync_run.id)
          rescue Spotify::Errors::RateLimitError
            # Expected
          end
        end.not_to have_enqueued_job(Playlists::FetchBatchJob)
      end
    end
  end

  describe 'retry behavior' do
    it 'includes SpotifyJobErrorHandling concern' do
      expect(described_class.ancestors).to include(SpotifyJobErrorHandling)
    end
  end
end
