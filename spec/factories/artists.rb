# frozen_string_literal: true

FactoryBot.define do
  factory :artist do
    sequence(:spotify_id) { |n| "spotify_artist_#{n}" }
    name { Faker::Music::Hiphop.artist }
    raw_data do
      {
        id: spotify_id,
        name: name,
        type: 'artist',
        uri: "spotify:artist:#{spotify_id}",
        href: "https://api.spotify.com/v1/artists/#{spotify_id}",
        external_urls: { spotify: "https://open.spotify.com/artist/#{spotify_id}" }
      }
    end
  end
end
