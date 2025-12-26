# frozen_string_literal: true

module Playlists
  class FetchPlaylistBatchService < ApplicationService
    def initialize(sync_run:, offset:, limit:)
      @sync_run = sync_run
      @offset = offset
      @limit = limit
      @spotify_client = Spotify::PlaylistClient.for_user(sync_run.user)
      @batch_processor = SpotifyBatchProcessor.new(sync_run: sync_run)
    end

    def call
      playlists = fetch_playlists_from_spotify
      batch_processor.process_batch(playlists)
      batch_processor.mark_batch_complete!
    end

    private

    attr_reader :sync_run, :offset, :limit, :spotify_client, :batch_processor

    def fetch_playlists_from_spotify
      response = spotify_client.fetch_user_playlists(limit: limit, offset: offset)
      response[:playlists]
    end
  end
end
