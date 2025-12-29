# frozen_string_literal: true

module Tracks
  class FetchTrackBatchService < ApplicationService
    def initialize(sync_run:, offset:, limit:, snapshot_id:)
      @sync_run = sync_run
      @playlist = sync_run.playlist
      @offset = offset
      @limit = limit
      @snapshot_id = snapshot_id
      @spotify_client = Spotify::TrackClient.for_user(playlist.user)
      @batch_processor = SpotifyBatchProcessor.new(sync_run: sync_run)
    end

    def call
      response = spotify_client.fetch_playlist_with_tracks(
        playlist.spotify_id,
        limit: limit,
        offset: offset
      )

      batch_processor.process_track_batch(response[:tracks])
      sync_run.increment_batch_completion!
      return unless sync_run.completed?

      playlist.mark_tracks_synced!(snapshot_id)
    end

    private

    attr_reader :sync_run, :playlist, :offset, :limit, :snapshot_id, :spotify_client, :batch_processor
  end
end
