# frozen_string_literal: true

class CreateSpotifyPlaylistService < ApplicationService
  attr_reader :user, :name, :description, :public

  def initialize(user, name:, description: nil, public: true)
    @user = user
    @name = name
    @description = description
    @public = public
  end

  def call
    spotify_playlist_data = create_on_spotify
    create_local_playlist(spotify_playlist_data)
  end

  private

  def create_on_spotify
    client = Spotify::PlaylistClient.for_user(user)
    client.create_playlist(name: name, description: description, public: public)
  end

  def create_local_playlist(playlist_data)
    user.playlists.create!(
      spotify_id: playlist_data[:spotify_id],
      name: playlist_data[:name],
      description: playlist_data[:description],
      raw_data: playlist_data
    )
  end
end
