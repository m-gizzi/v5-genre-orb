# frozen_string_literal: true

module Tracks
  class ProcessPlaylistService < ApplicationService
    BATCH_SIZE = 100

    def initialize(sync_run:, force: false)
      @sync_run = sync_run
      @playlist = sync_run.playlist
      @force = force
      @spotify_client = Spotify::TrackClient.for_user(playlist.user)
      @batch_processor = SpotifyBatchProcessor.new(sync_run: sync_run)
    end

    def call
      sync_run.start_fetching_metadata!

      first_batch_response = fetch_first_batch
      current_snapshot_id = first_batch_response[:snapshot_id]
      playlist.update_snapshot_if_changed!(current_snapshot_id)

      unless force || playlist.snapshot_changed_since_last_track_sync?(current_snapshot_id)
        sync_run.update!(batches_total: 0)
        sync_run.complete!
        return
      end

      playlist.playlist_tracks.destroy_all
      calculate_and_set_totals(first_batch_response)
      sync_run.start_processing_batches!

      batch_processor.process_track_batch(first_batch_response[:tracks])
      sync_run.increment_batch_completion!

      enqueue_remaining_batches(current_snapshot_id)
    end

    private

    attr_reader :sync_run, :playlist, :force, :spotify_client, :batch_processor

    def fetch_first_batch
      spotify_client.fetch_playlist_with_tracks(
        playlist.spotify_id,
        limit: BATCH_SIZE,
        offset: 0
      )
    end

    def calculate_and_set_totals(response)
      total_tracks = response[:pagination][:total]
      batches_total = (total_tracks.to_f / BATCH_SIZE).ceil

      sync_run.update!(batches_total: batches_total)
    end

    def enqueue_remaining_batches(current_snapshot_id)
      (1...sync_run.batches_total).each do |batch_index|
        offset = batch_index * BATCH_SIZE
        Tracks::FetchTrackBatchJob.perform_later(sync_run.id, offset, BATCH_SIZE, current_snapshot_id)
      end
    end
  end
end
