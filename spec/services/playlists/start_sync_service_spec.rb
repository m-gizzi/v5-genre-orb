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

    it 'enqueues CoordinatorJob with sync_run id' do
      sync_run = described_class.call(user)
      expect(Playlists::CoordinatorJob).to have_been_enqueued.with(sync_run.id)
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
  end
end
