# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaylistSyncRun do
  describe '.in_progress_for_user' do
    let(:user) { create(:user) }
    let!(:user_sync) { create(:playlist_sync_run, user: user, status: :processing_batches) }
    let!(:user_completed) { create(:playlist_sync_run, user: user, status: :completed) }

    it 'returns the in-progress sync for the specified user' do
      expect(described_class.in_progress_for_user(user)).to eq(user_sync)
    end

    it 'does not return completed syncs' do
      expect(described_class.in_progress_for_user(user)).not_to eq(user_completed)
    end

    it 'returns nil when no in-progress sync exists' do
      user2 = create(:user)
      expect(described_class.in_progress_for_user(user2)).to be_nil
    end
  end

  describe '#increment_batch_completion!' do
    let(:sync) { create(:playlist_sync_run, :processing_batches, batches_total: 3, batches_completed: 1) }

    before do
      allow(Playlists::ArchiveMissingJob).to receive(:perform_later)
    end

    it 'increments batches_completed counter' do
      expect { sync.increment_batch_completion! }.to change { sync.reload.batches_completed }.by(1)
    end

    context 'when all batches are not yet completed' do
      it 'does not transition to archiving' do
        sync.increment_batch_completion!
        expect(sync.reload).to be_processing_batches
      end
    end

    context 'when this is the last batch' do
      before do
        sync.update!(batches_completed: 2)
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
  end

  describe 'AASM state transitions' do
    let(:sync_run) { create(:playlist_sync_run) }

    describe '#start_fetching_metadata!' do
      it 'sets started_at timestamp' do
        freeze_time do
          sync_run.start_fetching_metadata!
          expect(sync_run.started_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    describe '#start_archiving!' do
      let(:sync_run) do
        create(:playlist_sync_run,
               status: :processing_batches,
               batches_total: 3,
               batches_completed: 3)
      end

      before do
        allow(Playlists::ArchiveMissingJob).to receive(:perform_later)
      end

      it 'enqueues ArchiveMissingJob' do
        sync_run.start_archiving!
        expect(Playlists::ArchiveMissingJob).to have_received(:perform_later).with(sync_run.id)
      end
    end

    describe '#complete!' do
      it 'sets completed_at timestamp' do
        sync_run.update!(status: :archiving)
        freeze_time do
          sync_run.complete!
          expect(sync_run.completed_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    describe '#fail!' do
      it 'sets error_message when provided' do
        sync_run.fail!('Authentication failed')
        expect(sync_run.error_message).to eq('Authentication failed')
      end
    end

    describe '#may_start_archiving?' do
      it 'returns true when all conditions met' do
        sync_run.update!(
          status: :processing_batches,
          batches_total: 3,
          batches_completed: 3
        )
        expect(sync_run.may_start_archiving?).to be true
      end

      it 'returns false when batches not completed' do
        sync_run.update!(
          status: :processing_batches,
          batches_total: 3,
          batches_completed: 1
        )
        expect(sync_run.may_start_archiving?).to be false
      end

      it 'returns false when in wrong state' do
        sync_run.update!(
          status: :pending,
          batches_total: 3,
          batches_completed: 3
        )
        expect(sync_run.may_start_archiving?).to be false
      end
    end
  end
end
