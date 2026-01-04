# frozen_string_literal: true

class TrackSyncRun < ApplicationRecord
  include AASM

  belongs_to :playlist

  IN_PROGRESS_STATUSES = %i[pending fetching_metadata processing_batches].freeze

  validates :status, presence: true

  scope :in_progress, -> { where(status: IN_PROGRESS_STATUSES) }

  enum :status, {
    pending: 0,
    fetching_metadata: 1,
    processing_batches: 2,
    archiving: 3,
    completed: 4,
    failed: 5
  }, validate: true

  aasm column: :status, enum: true do
    state :pending, initial: true
    state :fetching_metadata
    state :processing_batches
    state :completed
    state :failed

    event :start_fetching_metadata do
      before { self.started_at = Time.current }
      transitions from: :pending, to: :fetching_metadata
    end

    event :start_processing_batches do
      transitions from: :fetching_metadata, to: :processing_batches
    end

    event :complete do
      before { self.completed_at = Time.current }
      after { playlist.mark_tracks_synced!(playlist.snapshot_id) }
      transitions from: :processing_batches,
                  to: :completed,
                  guard: :all_batches_completed?
    end

    event :fail do
      before { |msg| self.error_message = msg if msg }
      transitions from: IN_PROGRESS_STATUSES, to: :failed
    end
  end

  def self.in_progress_for_playlist(playlist)
    in_progress.find_by(playlist: playlist)
  end

  def increment_batch_completion!
    with_lock do
      increment!(:batches_completed)
      complete! if may_complete?
    end
  end

  def all_batches_completed?
    batches_completed >= batches_total && batches_total.positive?
  end
end
