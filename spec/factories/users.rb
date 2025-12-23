# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:spotify_id) { |n| "spotify_user_#{n}" }
    sequence(:spotify_email) { |n| "user#{n}@spotify.com" }
    spotify_display_name { Faker::Name.name }
    access_token { SecureRandom.hex(32) }
    refresh_token { SecureRandom.hex(32) }
    token_expires_at { 1.hour.from_now }

    trait :token_expired do
      token_expires_at { 10.minutes.ago }
    end
  end
end
