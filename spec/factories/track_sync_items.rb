# frozen_string_literal: true

FactoryBot.define do
  factory :track_sync_item do
    track_sync_run
    track
  end
end
