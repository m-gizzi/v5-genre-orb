# frozen_string_literal: true

FactoryBot.define do
  factory :playlist_sync_run do
    user
    status { :pending }
    total_playlists_expected { 0 }
    playlists_fetched { 0 }
    playlists_processed { 0 }
    batches_total { 0 }
    batches_completed { 0 }
    metadata { {} }

    trait :fetching_metadata do
      status { :fetching_metadata }
      started_at { Time.current }
    end

    trait :processing_batches do
      status { :processing_batches }
      started_at { Time.current }
      total_playlists_expected { 150 }
      batches_total { 3 }
    end

    trait :archiving do
      status { :archiving }
      started_at { Time.current }
      total_playlists_expected { 150 }
      playlists_fetched { 150 }
      playlists_processed { 150 }
      batches_total { 3 }
      batches_completed { 3 }
    end

    trait :completed do
      status { :completed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      total_playlists_expected { 150 }
      playlists_fetched { 150 }
      playlists_processed { 150 }
      batches_total { 3 }
      batches_completed { 3 }
    end

    trait :failed do
      status { :failed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      error_message { 'Authentication failed' }
    end

    trait :stale do
      status { :processing_batches }
      started_at { 2.hours.ago }
      created_at { 2.hours.ago }
    end
  end
end
