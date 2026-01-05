# frozen_string_literal: true

FactoryBot.define do
  factory :playlist_track do
    playlist
    track
    added_at { Faker::Time.between(from: 1.year.ago, to: Time.current) }
    sequence(:added_by_spotify_id) { |n| "spotify_user_#{n}" }
  end
end
