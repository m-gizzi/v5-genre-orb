# frozen_string_literal: true

FactoryBot.define do
  factory :playlist_sync_item do
    playlist_sync_run
    playlist
  end
end
