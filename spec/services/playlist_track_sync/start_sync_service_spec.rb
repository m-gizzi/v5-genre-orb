# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaylistTrackSync::StartSyncService do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user, snapshot_id: 'snapshot_123') }
  let(:facade) { class_double(FetchAndPersistFacade) }

  before do
    stub_const('FetchAndPersistFacade', facade)
  end

  describe '#call' do
    context 'when playlist snapshot has not changed' do
      before do
        playlist.update!(last_track_sync_snapshot_id: 'snapshot_123')
        allow(facade).to receive(:single_playlist).and_return({ counts: {} })
      end

      it 'does not create a new TrackSyncRun' do
        expect do
          described_class.call(playlist)
        end.not_to change(TrackSyncRun, :count)
      end

      it 'returns nil' do
        result = described_class.call(playlist)
        expect(result).to be_nil
      end
    end

    context 'when playlist snapshot has changed' do
      before do
        playlist.update!(last_track_sync_snapshot_id: 'old_snapshot')
        allow(facade).to receive(:single_playlist).and_return({ counts: {} })
      end

      it 'creates a new TrackSyncRun' do
        expect do
          described_class.call(playlist)
        end.to change(TrackSyncRun, :count).by(1)
      end

      it 'sets status to pending' do
        sync_run = described_class.call(playlist)
        expect(sync_run).to be_pending
      end

      it 'associates sync_run with playlist' do
        sync_run = described_class.call(playlist)
        expect(sync_run.playlist).to eq(playlist)
      end

      it 'enqueues CoordinatorJob with sync_run id' do
        sync_run = described_class.call(playlist)
        expect(PlaylistTrackSync::CoordinatorJob).to have_been_enqueued.with(sync_run.id)
      end
    end

    context 'when playlist has never been synced' do
      before do
        playlist.update!(last_track_sync_snapshot_id: nil)
        allow(facade).to receive(:single_playlist).and_return({ counts: {} })
      end

      it 'creates a new TrackSyncRun' do
        expect do
          described_class.call(playlist)
        end.to change(TrackSyncRun, :count).by(1)
      end
    end

    context 'when force option is true' do
      before do
        playlist.update!(last_track_sync_snapshot_id: 'snapshot_123')
      end

      it 'creates a new sync without checking snapshot' do
        expect(facade).not_to receive(:single_playlist)
        expect do
          described_class.call(playlist, force: true)
        end.to change(TrackSyncRun, :count).by(1)
      end
    end

    context 'when playlist already has in-progress sync' do
      let!(:existing_sync) { create(:track_sync_run, playlist: playlist, status: :processing_batches) }

      before do
        allow(facade).to receive(:single_playlist).and_return({ counts: {} })
        playlist.update!(last_track_sync_snapshot_id: 'old_snapshot')
      end

      it 'does not create a new sync_run' do
        expect do
          described_class.call(playlist)
        end.not_to change(TrackSyncRun, :count)
      end

      it 'returns the existing sync_run' do
        sync_run = described_class.call(playlist)
        expect(sync_run).to eq(existing_sync)
      end

      it 'does not enqueue CoordinatorJob' do
        expect do
          described_class.call(playlist)
        end.not_to have_enqueued_job(PlaylistTrackSync::CoordinatorJob)
      end
    end

    context 'when API error occurs during snapshot check' do
      before do
        allow(facade).to receive(:single_playlist).and_raise(Spotify::Errors::ApiError.new('API error'))
      end

      it 'creates a new sync_run despite error' do
        expect do
          described_class.call(playlist)
        end.to change(TrackSyncRun, :count).by(1)
      end
    end

    context 'when authentication error occurs during snapshot check' do
      before do
        allow(facade).to receive(:single_playlist).and_raise(Spotify::Errors::AuthenticationError.new('Auth failed'))
      end

      it 'creates a new sync_run despite error' do
        expect do
          described_class.call(playlist)
        end.to change(TrackSyncRun, :count).by(1)
      end
    end

    context 'when RecordNotUnique race condition occurs' do
      let!(:existing_sync) { create(:track_sync_run, playlist: playlist, status: :processing_batches) }

      before do
        allow(facade).to receive(:single_playlist).and_return({ counts: {} })
        playlist.update!(last_track_sync_snapshot_id: 'old_snapshot')

        # Simulate race condition: first call to in_progress_for_playlist returns nil,
        # then create! raises RecordNotUnique, then second call finds the existing record
        allow(TrackSyncRun).to receive(:in_progress_for_playlist).with(playlist).and_return(nil, existing_sync)
        allow(TrackSyncRun).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
      end

      it 'returns the existing sync_run' do
        sync_run = described_class.call(playlist)
        expect(sync_run).to eq(existing_sync)
      end
    end
  end
end
