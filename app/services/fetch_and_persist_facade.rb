# frozen_string_literal: true

class FetchAndPersistFacade < ApplicationService
  class << self
    def user_playlist_batch(user:, limit:, offset:)
      client = Spotify::PlaylistClient.for_user(user)
      repository = Spotify::PlaylistRepository.new(user: user)

      response = client.fetch_user_playlists(limit: limit, offset: offset)
      result = repository.process_batch(response[:items])

      {
        counts: result[:counts],
        item_ids: result[:item_ids],
        pagination: response[:pagination]
      }
    end

    def single_playlist(user:, spotify_id:)
      client = Spotify::PlaylistClient.for_user(user)
      repository = Spotify::PlaylistRepository.new(user: user)

      raw_data = client.fetch_playlist(spotify_id)
      result = repository.process_single(raw_data)

      {
        counts: result[:counts]
      }
    end

    def playlist_track_batch(user:, playlist:, limit:, offset:)
      client = Spotify::TrackClient.for_user(user)
      repository = Spotify::TrackRepository.new(playlist: playlist)

      response = client.fetch_playlist_tracks(playlist, limit: limit, offset: offset)
      result = repository.process_batch(response[:items])

      {
        counts: result[:counts],
        pagination: response[:pagination],
        item_ids: result[:item_ids]
      }
    end
  end
end
