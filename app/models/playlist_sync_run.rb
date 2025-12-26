# frozen_string_literal: true

class PlaylistSyncRun < ApplicationRecord
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

  validates :total_playlists_expected, numericality: { greater_than_or_equal_to: 0 }
  validates :playlists_fetched, numericality: { greater_than_or_equal_to: 0 }
  validates :playlists_processed, numericality: { greater_than_or_equal_to: 0 }
  validates :batches_total, numericality: { greater_than_or_equal_to: 0 }
  validates :batches_completed, numericality: { greater_than_or_equal_to: 0 }

  scope :in_progress, -> { where(status: IN_PROGRESS_STATUSES) }
  scope :recent, -> { order(created_at: :desc) }
  scope :stale, -> { in_progress.where(created_at: ...1.hour.ago) }

  def self.in_progress_for_user(user)
    where(user: user).in_progress.recent.first
  end

  def in_progress?
    IN_PROGRESS_STATUSES.include?(status.to_sym)
  end

  def progress_percentage
    return 0 if batches_total.zero?

    (batches_completed.to_f / batches_total * 100).round(2)
  end

  def increment_batch_completion!
    with_lock do
      increment!(:batches_completed)
      check_and_transition_to_archival! if all_batches_completed?
    end
  end

  def mark_batch_error!(batch_offset, error_message)
    with_lock do
      errors = metadata.fetch('batch_errors', {})
      errors[batch_offset.to_s] = {
        'message' => error_message,
        'timestamp' => Time.current.iso8601
      }
      update!(metadata: metadata.merge('batch_errors' => errors))
    end
  end

  def all_batches_completed?
    batches_completed >= batches_total && batches_total.positive?
  end

  private

  def check_and_transition_to_archival!
    return unless processing_batches? && all_batches_completed?

    update!(status: :archiving)
    Playlists::ArchiveMissingJob.perform_later(id)
  end
end
