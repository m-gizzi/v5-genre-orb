# frozen_string_literal: true

module Playlists
  class CoordinatePlaylistSyncService < ApplicationService
    BATCH_SIZE = 50

    def initialize(sync_run:)
      @sync_run = sync_run
      @spotify_client = Spotify::PlaylistClient.for_user(sync_run.user)
      @batch_processor = SpotifyBatchProcessor.new(sync_run: sync_run)
    end

    def call
      transition_to_fetching_metadata!
      first_batch_response = fetch_first_batch
      calculate_and_set_totals(first_batch_response)
      transition_to_processing_batches! # Should I consider a state machine?
      process_first_batch(first_batch_response[:playlists])
      enqueue_remaining_batch_jobs
    end

    private

    attr_reader :sync_run, :spotify_client, :batch_processor

    def transition_to_fetching_metadata!
      sync_run.update!(status: :fetching_metadata, started_at: Time.current)
    end

    def fetch_first_batch
      spotify_client.fetch_user_playlists(limit: BATCH_SIZE, offset: 0)
    end

    def calculate_and_set_totals(first_batch_response)
      total_count = first_batch_response[:pagination][:total]
      batches_needed = calculate_batches_needed(total_count)

      sync_run.update!(
        total_playlists_expected: total_count,
        batches_total: batches_needed
      )
    end

    def calculate_batches_needed(total_count)
      return 1 if total_count.zero?

      (total_count.to_f / BATCH_SIZE).ceil
    end

    def process_first_batch(playlists)
      batch_processor.process_batch(playlists)
      batch_processor.mark_batch_complete!
    end

    def transition_to_processing_batches!
      sync_run.update!(status: :processing_batches)
    end

    def enqueue_remaining_batch_jobs
      batches_total = sync_run.batches_total

      (1...batches_total).each do |batch_index|
        offset = batch_index * BATCH_SIZE
        Playlists::FetchBatchJob.perform_later(sync_run.id, offset, BATCH_SIZE)
      end
    end
  end
end
