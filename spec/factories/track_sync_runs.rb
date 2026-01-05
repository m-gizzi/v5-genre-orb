# frozen_string_literal: true

FactoryBot.define do
  factory :track_sync_run do
    playlist
    status { :pending }
    batches_total { 0 }
    batches_completed { 0 }
    tracks_processed { 0 }
    artists_processed { 0 }

    trait :fetching_metadata do
      status { :fetching_metadata }
      started_at { Time.current }
    end

    trait :processing_batches do
      status { :processing_batches }
      started_at { Time.current }
      batches_total { 3 }
      batches_completed { 1 }
    end

    trait :archiving do
      status { :archiving }
      started_at { 1.hour.ago }
      batches_total { 3 }
      batches_completed { 3 }
      tracks_processed { 150 }
      artists_processed { 75 }
    end

    trait :completed do
      status { :completed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      batches_total { 3 }
      batches_completed { 3 }
      tracks_processed { 150 }
      artists_processed { 75 }
    end

    trait :failed do
      status { :failed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      error_message { 'Spotify API authentication failed' }
    end
  end
end
