# frozen_string_literal: true

module Tracks
  class FetchAndPersistService < ApplicationService
    def fetch_and_persist_batch(user:, playlist:, limit:, offset:)
      client = Spotify::TrackClient.for_user(user)
      repository = Spotify::TrackRepository.new(playlist: playlist)

      response = client.fetch_playlist_tracks(playlist, limit: limit, offset: offset)
      result = repository.process_batch(response[:items])

      {
        counts: result[:counts],
        pagination: response[:pagination]
      }
    end
  end
end
