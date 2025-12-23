# frozen_string_literal: true

class SyncUserPlaylistsService < ApplicationService
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call
    spotify_playlists = fetch_all_playlists
    sync_playlists(spotify_playlists)
  end

  private

  def fetch_all_playlists
    client = Spotify::PlaylistClient.for_user(user)
    client.fetch_all_user_playlists
  end

  def sync_playlists(spotify_playlists)
    ApplicationRecord.transaction do
      spotify_ids = spotify_playlists.map { |p| p[:spotify_id] }

      synced_playlists = spotify_playlists.map do |playlist_data|
        upsert_playlist(playlist_data)
      end

      archive_missing_playlists(spotify_ids)

      synced_playlists
    end
  end

  def upsert_playlist(playlist_data)
    user.playlists.find_or_initialize_by(spotify_id: playlist_data[:spotify_id]).tap do |playlist|
      playlist.name = playlist_data[:name]
      playlist.description = playlist_data[:description]
      playlist.raw_data = playlist_data
      playlist.archived_at = nil
      playlist.save!
    end
  end

  def archive_missing_playlists(current_spotify_ids)
    user.playlists
        .active
        .where.not(spotify_id: current_spotify_ids)
        .update_all(archived_at: Time.current)
  end
end
