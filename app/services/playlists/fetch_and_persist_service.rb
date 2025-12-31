# frozen_string_literal: true

module Playlists
  class FetchAndPersistService < ApplicationService
    def fetch_and_persist_batch(user:, limit:, offset:)
      client = Spotify::PlaylistClient.for_user(user)
      repository = Spotify::PlaylistRepository.new(user: user)

      response = client.fetch_user_playlists(limit: limit, offset: offset)
      result = repository.process_batch(response[:items])

      {
        counts: result[:counts],
        playlist_ids: result[:playlist_ids],
        pagination: response[:pagination]
      }
    end
  end
end
