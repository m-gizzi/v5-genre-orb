# frozen_string_literal: true

module Playlists
  class CoordinatorJob < ApplicationJob
    include SpotifyJobErrorHandling

    queue_as :default

    BATCH_SIZE = 50

    def perform(sync_run_id)
      @sync_run = PlaylistSyncRun.find(sync_run_id)
      @user = @sync_run.user

      fetch_metadata_and_enqueue_batches
    end

    private

    attr_reader :sync_run, :user

    def fetch_metadata_and_enqueue_batches
      transition_to_fetching_metadata!
      first_batch = fetch_first_batch
      calculate_and_set_totals(first_batch)
      enqueue_batch_jobs
      transition_to_processing_batches!
    end

    def transition_to_fetching_metadata!
      sync_run.update!(status: :fetching_metadata, started_at: Time.current)
    end

    def fetch_first_batch
      client = Spotify::PlaylistClient.for_user(user)
      client.fetch_user_playlists(limit: BATCH_SIZE, offset: 0)
    end

    def calculate_and_set_totals(first_batch)
      # For now, we estimate based on first batch
      # TODO: Enhance PlaylistClient to return total count from API response
      total_count = estimate_total_count(first_batch)
      batches_needed = calculate_batches_needed(total_count)

      sync_run.update!(
        total_playlists_expected: total_count,
        batches_total: batches_needed
      )
    end

    def estimate_total_count(first_batch)
      # If first batch has fewer than BATCH_SIZE items, that's all there is
      return first_batch.size if first_batch.size < BATCH_SIZE

      # Otherwise, estimate based on pattern (will be refined as batches complete)
      # For now, assume at least one more batch exists
      BATCH_SIZE
    end

    def calculate_batches_needed(total_count)
      return 1 if total_count.zero?

      (total_count.to_f / BATCH_SIZE).ceil
    end

    def enqueue_batch_jobs
      batches_total = sync_run.batches_total

      batches_total.times do |batch_index|
        offset = batch_index * BATCH_SIZE
        Playlists::FetchBatchJob.perform_later(sync_run.id, offset, BATCH_SIZE)
      end
    end

    def transition_to_processing_batches!
      sync_run.update!(status: :processing_batches)
    end
  end
end
