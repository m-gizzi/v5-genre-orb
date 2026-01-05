# frozen_string_literal: true

module Spotify
  class TrackRepository < BaseRepository
    attr_reader :playlist

    def initialize(playlist:)
      super()
      @playlist = playlist
    end

    def process_batch(raw_items)
      item_ids = []

      raw_items.each do |raw_item|
        track = process_track_item(raw_item)
        item_ids << track.id if track
      end

      {
        counts: counts_hash,
        item_ids: item_ids
      }
    end

    private

    def process_track_item(raw_item)
      track_data = raw_item['track']
      return nil if track_data.nil?

      track = upsert_track(track_data)
      process_track_artists(track, track_data['artists'] || [])
      upsert_playlist_track(track, raw_item)

      increment_count(:tracks_processed)
      track
    end

    def upsert_track(track_data)
      track = Track.find_or_initialize_by(spotify_id: track_data['id'])
      track.assign_attributes(
        name: track_data['name'],
        duration_ms: track_data['duration_ms'],
        disc_number: track_data['disc_number'],
        track_number: track_data['track_number'],
        explicit: track_data['explicit'],
        is_local: track_data['is_local'],
        popularity: track_data['popularity'],
        preview_url: track_data['preview_url'],
        isrc: track_data.dig('external_ids', 'isrc'),
        raw_data: track_data
      )
      track.save!
      track
    end

    def process_track_artists(track, artists_data)
      track.track_artists.destroy_all

      artists_data.each do |artist_data|
        artist = upsert_artist(artist_data)

        TrackArtist.create!(
          track: track,
          artist: artist
        )

        increment_count(:artists_processed)
      end
    end

    def upsert_artist(artist_data)
      Artist.find_or_create_by!(spotify_id: artist_data['id']) do |artist|
        artist.name = artist_data['name']
        artist.raw_data = artist_data
      end
    end

    def upsert_playlist_track(track, raw_item)
      playlist_track = PlaylistTrack.find_or_initialize_by(
        playlist: playlist,
        track: track
      )

      playlist_track.assign_attributes(
        added_at: raw_item['added_at'],
        added_by_spotify_id: raw_item.dig('added_by', 'id')
      )

      playlist_track.save!
    end
  end
end
