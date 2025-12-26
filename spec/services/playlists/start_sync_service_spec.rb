# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Playlists::StartSyncService do
  let(:user) { create(:user) }

  describe '#call' do
    it 'creates a new PlaylistSyncRun' do
      expect do
        described_class.call(user)
      end.to change(PlaylistSyncRun, :count).by(1)
    end

    it 'sets status to pending' do
      sync_run = described_class.call(user)
      expect(sync_run).to be_pending
    end

    it 'associates sync_run with user' do
      sync_run = described_class.call(user)
      expect(sync_run.user).to eq(user)
    end

    it 'enqueues CoordinatorJob' do
      expect do
        described_class.call(user)
      end.to have_enqueued_job(Playlists::CoordinatorJob)
    end

    it 'enqueues CoordinatorJob with sync_run id' do
      sync_run = described_class.call(user)
      expect(Playlists::CoordinatorJob).to have_been_enqueued.with(sync_run.id)
    end

    it 'returns the created sync_run' do
      sync_run = described_class.call(user)
      expect(sync_run).to be_a(PlaylistSyncRun)
      expect(sync_run).to be_persisted
    end

    context 'when user already has in-progress sync' do
      let!(:existing_sync) { create(:playlist_sync_run, user: user, status: :processing_batches) }

      it 'does not create a new sync_run' do
        expect do
          described_class.call(user)
        end.not_to change(PlaylistSyncRun, :count)
      end

      it 'returns the existing sync_run' do
        sync_run = described_class.call(user)
        expect(sync_run).to eq(existing_sync)
      end

      it 'does not enqueue CoordinatorJob' do
        expect do
          described_class.call(user)
        end.not_to have_enqueued_job(Playlists::CoordinatorJob)
      end
    end

    context 'when user has completed sync' do
      let!(:completed_sync) { create(:playlist_sync_run, user: user, status: :completed) }

      it 'creates a new sync_run' do
        expect do
          described_class.call(user)
        end.to change(PlaylistSyncRun, :count).by(1)
      end

      it 'enqueues CoordinatorJob for new sync' do
        expect do
          described_class.call(user)
        end.to have_enqueued_job(Playlists::CoordinatorJob)
      end
    end

    context 'when user has failed sync' do
      let!(:failed_sync) { create(:playlist_sync_run, user: user, status: :failed) }

      it 'creates a new sync_run' do
        expect do
          described_class.call(user)
        end.to change(PlaylistSyncRun, :count).by(1)
      end

      it 'enqueues CoordinatorJob for new sync' do
        expect do
          described_class.call(user)
        end.to have_enqueued_job(Playlists::CoordinatorJob)
      end
    end

    context 'when concurrent requests create race condition' do
      it 'handles RecordNotUnique gracefully' do
        # Simulate race condition by creating sync during the check
        allow(PlaylistSyncRun).to receive(:in_progress_for_user).and_return(nil, nil)
        allow(PlaylistSyncRun).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        # Should rescue and query again
        existing = create(:playlist_sync_run, user: user, status: :pending)
        allow(PlaylistSyncRun).to receive(:in_progress_for_user).and_return(existing)

        sync_run = described_class.call(user)
        expect(sync_run).to eq(existing)
      end
    end

    context 'with multiple users' do
      let(:user1) { create(:user) }
      let(:user2) { create(:user) }

      it 'allows concurrent syncs for different users' do
        sync1 = described_class.call(user1)
        sync2 = described_class.call(user2)

        expect(sync1.user).to eq(user1)
        expect(sync2.user).to eq(user2)
        expect(sync1).not_to eq(sync2)
      end
    end
  end
end
