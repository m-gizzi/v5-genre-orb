# frozen_string_literal: true

module Tracks
  class SpotifyBatchProcessor
    BATCH_SIZE = 100

    attr_reader :sync_run, :playlist

    def initialize(sync_run:)
      @sync_run = sync_run
      @playlist = sync_run.playlist
    end

    def process_track_batch(track_items)
      track_items.each do |item|
        track_data = item[:track]

        track = upsert_track(track_data)
        process_track_artists(track, track_data[:artists])
        create_playlist_track(track, item)
        increment_progress_counter(:tracks_processed)
      end
    end

    private

    def upsert_track(track_data)
      track = Track.find_or_initialize_by(spotify_id: track_data[:spotify_id]) # We can probaby stop if the track already exists
      track.assign_attributes(
        name: track_data[:name],
        duration_ms: track_data[:duration_ms],
        disc_number: track_data[:disc_number],
        track_number: track_data[:track_number],
        explicit: track_data[:explicit],
        is_local: track_data[:is_local],
        popularity: track_data[:popularity],
        preview_url: track_data[:preview_url],
        isrc: track_data[:isrc],
        raw_data: track_data
      )
      track.save!
      track
    end

    def process_track_artists(track, artists_data)
      track.track_artists.destroy_all # This is going to be way too much to do for every track, every playlist

      artists_data.each do |artist_data|
        artist = upsert_artist(artist_data)

        TrackArtist.create!(
          track: track,
          artist: artist
        )

        increment_progress_counter(:artists_processed)
      end
    end

    def upsert_artist(artist_data)
      Artist.find_or_create_by!(spotify_id: artist_data[:spotify_id]) do |artist|
        artist.name = artist_data[:name]
        artist.raw_data = artist_data
      end
    end

    def create_playlist_track(track, item)
      PlaylistTrack.create!(
        playlist: playlist,
        track: track,
        added_at: item[:added_at],
        added_by_spotify_id: item[:added_by_spotify_id]
      )
    end

    def increment_progress_counter(counter_name)
      sync_run.with_lock do
        sync_run.increment!(counter_name)
      end
    end
  end
end
