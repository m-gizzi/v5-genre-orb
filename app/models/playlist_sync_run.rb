# frozen_string_literal: true

class PlaylistSyncRun < ApplicationRecord
  include AASM

  belongs_to :user
  has_many :playlist_sync_items, dependent: :destroy
  has_many :playlists, through: :playlist_sync_items

  IN_PROGRESS_STATUSES = %i[pending fetching_metadata processing_batches archiving].freeze

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
    state :archiving
    state :completed
    state :failed

    event :start_fetching_metadata do
      before do
        self.started_at = Time.current
      end

      transitions from: :pending, to: :fetching_metadata
    end

    event :start_processing_batches do
      transitions from: :fetching_metadata, to: :processing_batches
    end

    event :start_archiving do
      after do
        Playlists::ArchiveMissingJob.perform_later(id)
      end

      transitions from: :processing_batches, to: :archiving, guard: :all_batches_completed?
    end

    event :complete do
      before do
        self.completed_at = Time.current
      end

      transitions from: :archiving, to: :completed
    end

    event :fail do
      before do |error_msg = nil|
        self.error_message = error_msg if error_msg
      end

      transitions from: IN_PROGRESS_STATUSES, to: :failed
    end
  end

  validates :total_playlists_expected, numericality: { greater_than_or_equal_to: 0 }
  validates :playlists_fetched, numericality: { greater_than_or_equal_to: 0 }
  validates :playlists_processed, numericality: { greater_than_or_equal_to: 0 }
  validates :batches_total, numericality: { greater_than_or_equal_to: 0 }
  validates :batches_completed, numericality: { greater_than_or_equal_to: 0 }

  scope :in_progress, -> { where(status: IN_PROGRESS_STATUSES) }

  def self.in_progress_for_user(user)
    where(user: user).in_progress.first
  end

  def increment_batch_completion!
    with_lock do
      increment!(:batches_completed)
      start_archiving! if may_start_archiving?
    end
  end

  def all_batches_completed?
    batches_completed >= batches_total && batches_total.positive?
  end
end
