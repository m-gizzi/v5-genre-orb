# frozen_string_literal: true

FactoryBot.define do
  factory :playlist do
    user
    sequence(:spotify_id) { |n| "spotify_playlist_#{n}" }
    sequence(:name) { |n| "Playlist #{n}" }
    description { Faker::Lorem.sentence }
    raw_data do
      {
        spotify_id: spotify_id,
        name: name,
        description: description,
        public: true,
        collaborative: false,
        owner: {
          id: user.spotify_id,
          display_name: user.spotify_display_name,
          uri: "spotify:user:#{user.spotify_id}"
        },
        snapshot_id: SecureRandom.hex(16),
        tracks_total: rand(0..100),
        images: [],
        external_urls: { 'spotify' => "https://open.spotify.com/playlist/#{spotify_id}" },
        uri: "spotify:playlist:#{spotify_id}",
        href: "https://api.spotify.com/v1/playlists/#{spotify_id}"
      }
    end

    trait :archived do
      archived_at { 1.day.ago }
    end

    trait :without_description do
      description { nil }
    end

    trait :private_playlist do
      raw_data do
        {
          spotify_id: spotify_id,
          name: name,
          description: description,
          public: false,
          collaborative: false,
          owner: {
            id: user.spotify_id,
            display_name: user.spotify_display_name,
            uri: "spotify:user:#{user.spotify_id}"
          },
          snapshot_id: SecureRandom.hex(16),
          tracks_total: rand(0..100),
          images: [],
          external_urls: { 'spotify' => "https://open.spotify.com/playlist/#{spotify_id}" },
          uri: "spotify:playlist:#{spotify_id}",
          href: "https://api.spotify.com/v1/playlists/#{spotify_id}"
        }
      end
    end

    trait :collaborative do
      raw_data do
        {
          spotify_id: spotify_id,
          name: name,
          description: description,
          public: true,
          collaborative: true,
          owner: {
            id: user.spotify_id,
            display_name: user.spotify_display_name,
            uri: "spotify:user:#{user.spotify_id}"
          },
          snapshot_id: SecureRandom.hex(16),
          tracks_total: rand(0..100),
          images: [],
          external_urls: { 'spotify' => "https://open.spotify.com/playlist/#{spotify_id}" },
          uri: "spotify:playlist:#{spotify_id}",
          href: "https://api.spotify.com/v1/playlists/#{spotify_id}"
        }
      end
    end
  end
end
