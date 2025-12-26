# frozen_string_literal: true

module Playlists
  class CoordinatorJob < SyncRunJob
    queue_as :default

    BATCH_SIZE = 50

    def call
      fetch_metadata_and_enqueue_batches
    end

    private

    def fetch_metadata_and_enqueue_batches
      transition_to_fetching_metadata!
      first_batch = fetch_first_batch
      calculate_and_set_totals(first_batch)
      transition_to_processing_batches!
      enqueue_batch_jobs
    end

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
