# frozen_string_literal: true

module SyncRunStateMachine
  extend ActiveSupport::Concern

  IN_PROGRESS_STATUSES = %i[pending fetching_metadata processing_batches archiving].freeze

  included do
    include AASM

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
      state :archiving
      state :completed
      state :failed

      event :start_fetching_metadata do
        before { self.started_at = Time.current }
        transitions from: :pending, to: :fetching_metadata
      end

      event :start_processing_batches do
        transitions from: :fetching_metadata, to: :processing_batches
      end

      event :start_archiving do
        after { enqueue_cleanup_job }
        transitions from: :processing_batches, to: :archiving, guard: :all_batches_completed?
      end

      event :complete do
        before { self.completed_at = Time.current }
        after { on_completion }
        transitions from: :archiving, to: :completed
      end

      event :fail do
        before { |msg| self.error_message = msg if msg }
        transitions from: IN_PROGRESS_STATUSES, to: :failed
      end
    end
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

  def enqueue_cleanup_job
    raise NotImplementedError, "#{self.class} must implement #enqueue_cleanup_job"
  end

  def on_completion; end
end
