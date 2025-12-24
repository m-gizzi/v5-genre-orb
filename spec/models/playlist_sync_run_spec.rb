# frozen_string_literal: true

require 'rails_helper'

# Stub the job module/class since it doesn't exist yet
module Playlists
  class ArchiveMissingJob
    def self.perform_later(_id); end
  end
end

RSpec.describe PlaylistSyncRun do
  describe 'scopes' do
    describe '.in_progress' do
      let!(:pending_sync) { create(:playlist_sync_run, status: :pending) }
      let!(:processing_sync) { create(:playlist_sync_run, status: :processing_batches) }
      let!(:archiving_sync) { create(:playlist_sync_run, status: :archiving) }
      let!(:completed_sync) { create(:playlist_sync_run, status: :completed) }
      let!(:failed_sync) { create(:playlist_sync_run, status: :failed) }

      it 'returns only in-progress syncs' do
        expect(described_class.in_progress).to contain_exactly(
          pending_sync,
          processing_sync,
          archiving_sync
        )
      end

      it 'does not include completed syncs' do
        expect(described_class.in_progress).not_to include(completed_sync)
      end

      it 'does not include failed syncs' do
        expect(described_class.in_progress).not_to include(failed_sync)
      end
    end

    describe '.recent' do
      let!(:older_sync) { create(:playlist_sync_run, created_at: 2.hours.ago) }
      let!(:newer_sync) { create(:playlist_sync_run, created_at: 1.hour.ago) }
      let!(:newest_sync) { create(:playlist_sync_run, created_at: Time.current) }

      it 'returns syncs in descending order by created_at' do
        expect(described_class.recent).to eq([newest_sync, newer_sync, older_sync])
      end
    end

    describe '.stale' do
      let!(:stale_sync) { create(:playlist_sync_run, :stale) }
      let!(:recent_sync) { create(:playlist_sync_run, status: :processing_batches) }

      it 'returns in-progress syncs older than 1 hour' do
        expect(described_class.stale).to contain_exactly(stale_sync)
      end

      it 'does not include recent syncs' do
        expect(described_class.stale).not_to include(recent_sync)
      end
    end
  end

  describe '.in_progress_for_user' do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let!(:user1_sync) { create(:playlist_sync_run, user: user1, status: :processing_batches) }
    let!(:user2_sync) { create(:playlist_sync_run, user: user2, status: :processing_batches) }
    let!(:user1_completed) { create(:playlist_sync_run, user: user1, status: :completed) }

    it 'returns the most recent in-progress sync for the specified user' do
      expect(described_class.in_progress_for_user(user1)).to eq(user1_sync)
    end

    it 'does not return syncs for other users' do
      expect(described_class.in_progress_for_user(user1)).not_to eq(user2_sync)
    end

    it 'does not return completed syncs' do
      expect(described_class.in_progress_for_user(user1)).not_to eq(user1_completed)
    end

    it 'returns nil when no in-progress sync exists' do
      user3 = create(:user)
      expect(described_class.in_progress_for_user(user3)).to be_nil
    end
  end

  describe '#in_progress?' do
    it 'returns true for pending status' do
      sync = build(:playlist_sync_run, status: :pending)
      expect(sync).to be_in_progress
    end

    it 'returns true for fetching_metadata status' do
      sync = build(:playlist_sync_run, status: :fetching_metadata)
      expect(sync).to be_in_progress
    end

    it 'returns true for processing_batches status' do
      sync = build(:playlist_sync_run, status: :processing_batches)
      expect(sync).to be_in_progress
    end

    it 'returns true for archiving status' do
      sync = build(:playlist_sync_run, status: :archiving)
      expect(sync).to be_in_progress
    end

    it 'returns false for completed status' do
      sync = build(:playlist_sync_run, status: :completed)
      expect(sync).not_to be_in_progress
    end

    it 'returns false for failed status' do
      sync = build(:playlist_sync_run, status: :failed)
      expect(sync).not_to be_in_progress
    end
  end

  describe '#progress_percentage' do
    it 'returns 0 when batches_total is 0' do
      sync = build(:playlist_sync_run, batches_total: 0, batches_completed: 0)
      expect(sync.progress_percentage).to eq(0)
    end

    it 'calculates percentage correctly' do
      sync = build(:playlist_sync_run, batches_total: 10, batches_completed: 5)
      expect(sync.progress_percentage).to eq(50.0)
    end

    it 'rounds to 2 decimal places' do
      sync = build(:playlist_sync_run, batches_total: 3, batches_completed: 1)
      expect(sync.progress_percentage).to eq(33.33)
    end

    it 'returns 100 when all batches completed' do
      sync = build(:playlist_sync_run, batches_total: 10, batches_completed: 10)
      expect(sync.progress_percentage).to eq(100.0)
    end
  end

  describe '#increment_batch_completion!' do
    let(:sync) { create(:playlist_sync_run, :processing_batches, batches_total: 3, batches_completed: 1) }

    it 'increments batches_completed counter' do
      expect { sync.increment_batch_completion! }.to change { sync.reload.batches_completed }.by(1)
    end

    it 'uses database lock to prevent race conditions' do
      expect(sync).to receive(:with_lock).and_call_original
      sync.increment_batch_completion!
    end

    context 'when all batches are not yet completed' do
      it 'does not transition to archiving' do
        sync.increment_batch_completion!
        expect(sync.reload).to be_processing_batches
      end
    end

    context 'when this is the last batch' do
      before do
        sync.update!(batches_completed: 2) # One away from completion
        # Stub the job since it doesn't exist yet
        allow(Playlists::ArchiveMissingJob).to receive(:perform_later)
      end

      it 'transitions to archiving status' do
        sync.increment_batch_completion!
        expect(sync.reload).to be_archiving
      end

      it 'enqueues archival job with sync_run id' do
        sync.increment_batch_completion!
        expect(Playlists::ArchiveMissingJob).to have_received(:perform_later).with(sync.id)
      end
    end

    context 'when not in processing_batches status' do
      let(:completed_sync) { create(:playlist_sync_run, :completed) }

      it 'does not transition to archiving' do
        completed_sync.increment_batch_completion!
        expect(completed_sync.reload).to be_completed
      end
    end
  end

  describe '#mark_batch_error!' do
    let(:sync) { create(:playlist_sync_run) }
    let(:error_message) { 'Rate limit exceeded' }
    let(:batch_offset) { 50 }

    it 'stores error in metadata' do
      sync.mark_batch_error!(batch_offset, error_message)

      expect(sync.reload.metadata['batch_errors']['50']).to include(
        'message' => error_message
      )
    end

    it 'includes timestamp' do
      freeze_time do
        sync.mark_batch_error!(batch_offset, error_message)

        expect(sync.reload.metadata['batch_errors']['50']['timestamp'])
          .to eq(Time.current.iso8601)
      end
    end

    it 'uses database lock to prevent race conditions' do
      expect(sync).to receive(:with_lock).and_call_original
      sync.mark_batch_error!(batch_offset, error_message)
    end

    it 'allows multiple errors for different batches' do
      sync.mark_batch_error!(0, 'First error')
      sync.mark_batch_error!(50, 'Second error')

      errors = sync.reload.metadata['batch_errors']
      expect(errors.keys).to contain_exactly('0', '50')
    end
  end

  describe '#all_batches_completed?' do
    it 'returns true when batches_completed equals batches_total and positive' do
      sync = build(:playlist_sync_run, batches_total: 5, batches_completed: 5)
      expect(sync.all_batches_completed?).to be true
    end

    it 'returns false when batches_completed is less than batches_total' do
      sync = build(:playlist_sync_run, batches_total: 5, batches_completed: 3)
      expect(sync.all_batches_completed?).to be false
    end

    it 'returns false when batches_total is 0' do
      sync = build(:playlist_sync_run, batches_total: 0, batches_completed: 0)
      expect(sync.all_batches_completed?).to be false
    end

    it 'returns true when batches_completed exceeds batches_total' do
      sync = build(:playlist_sync_run, batches_total: 5, batches_completed: 6)
      expect(sync.all_batches_completed?).to be true
    end
  end
end
