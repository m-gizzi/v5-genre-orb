# frozen_string_literal: true

FactoryBot.define do
  factory :rate_limit_cooldown do
    endpoint { 'spotify:playlists' }
    expires_at { 1.minute.from_now }
    retry_after_seconds { 60 }

    trait :expired do
      expires_at { 1.minute.ago }
    end

    trait :in_progress do
      expires_at { 5.minutes.from_now }
      retry_after_seconds { 300 }
    end

    trait :for_tracks do
      endpoint { 'spotify:tracks' }
    end

    trait :for_artists do
      endpoint { 'spotify:artists' }
    end
  end
end
