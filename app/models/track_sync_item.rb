# frozen_string_literal: true

class TrackSyncItem < ApplicationRecord
  belongs_to :track_sync_run
  belongs_to :track

  validates :track_sync_run_id, uniqueness: { scope: :track_id }
end
