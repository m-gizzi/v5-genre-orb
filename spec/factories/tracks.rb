# frozen_string_literal: true

FactoryBot.define do
  factory :track do
    sequence(:spotify_id) { |n| "spotify_track_#{n}" }
    sequence(:name) { |n| "Track #{n}" }
    duration_ms { rand(120_000..300_000) }
    disc_number { 1 }
    track_number { rand(1..20) }
    explicit { false }
    is_local { false }
    popularity { rand(0..100) }
    preview_url { "https://p.scdn.co/mp3-preview/#{SecureRandom.hex(16)}" }
    isrc { "US#{Faker::Alphanumeric.alpha(number: 3).upcase}#{Faker::Number.number(digits: 7)}" }
    raw_data do
      {
        id: spotify_id,
        name: name,
        duration_ms: duration_ms,
        disc_number: disc_number,
        track_number: track_number,
        explicit: explicit,
        is_local: is_local,
        popularity: popularity,
        preview_url: preview_url,
        external_ids: { isrc: isrc },
        album: {
          name: Faker::Music.album,
          images: [
            { url: "https://i.scdn.co/image/#{SecureRandom.hex(20)}", height: 640, width: 640 },
            { url: "https://i.scdn.co/image/#{SecureRandom.hex(20)}", height: 300, width: 300 },
            { url: "https://i.scdn.co/image/#{SecureRandom.hex(20)}", height: 64, width: 64 }
          ],
          release_date: Faker::Date.between(from: '1960-01-01', to: Date.today).to_s
        },
        artists: [],
        external_urls: { spotify: "https://open.spotify.com/track/#{spotify_id}" },
        uri: "spotify:track:#{spotify_id}",
        href: "https://api.spotify.com/v1/tracks/#{spotify_id}"
      }
    end

    trait :with_artists do
      after(:create) do |track|
        create_list(:track_artist, 2, track: track)
      end
    end

    trait :explicit do
      explicit { true }
    end

    trait :local do
      is_local { true }
      spotify_id { "spotify:local:#{Faker::Music.artist}:#{Faker::Music.album}:#{name}:#{duration_ms}" }
    end
  end
end
