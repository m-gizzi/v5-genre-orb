# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TrackSyncRun do
  describe '.in_progress_for_playlist' do
    let(:playlist) { create(:playlist) }
    let!(:playlist_sync) { create(:track_sync_run, playlist: playlist, status: :processing_batches) }

    it 'returns the in-progress sync for the specified playlist' do
      expect(described_class.in_progress_for_playlist(playlist)).to eq(playlist_sync)
    end

    it 'returns nil when no in-progress sync exists' do
      playlist2 = create(:playlist)
      expect(described_class.in_progress_for_playlist(playlist2)).to be_nil
    end
  end

  describe '#increment_batch_completion!' do
    let(:sync) { create(:track_sync_run, :processing_batches, batches_total: 3, batches_completed: 1) }

    before do
      allow(PlaylistTrackSync::CleanupRemovedJob).to receive(:perform_later)
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

      it 'enqueues cleanup job with sync_run id' do
        sync.increment_batch_completion!
        expect(PlaylistTrackSync::CleanupRemovedJob).to have_received(:perform_later).with(sync.id)
      end
    end
  end

  describe 'AASM state transitions' do
    let(:sync_run) { create(:track_sync_run) }

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
        create(:track_sync_run,
               status: :processing_batches,
               batches_total: 3,
               batches_completed: 3)
      end

      before do
        allow(PlaylistTrackSync::CleanupRemovedJob).to receive(:perform_later)
      end

      it 'enqueues CleanupRemovedJob' do
        sync_run.start_archiving!
        expect(PlaylistTrackSync::CleanupRemovedJob).to have_received(:perform_later).with(sync_run.id)
      end
    end

    describe '#complete!' do
      let(:playlist) { create(:playlist, snapshot_id: 'snapshot_123') }
      let(:sync_run) { create(:track_sync_run, playlist: playlist, status: :archiving) }

      it 'sets completed_at timestamp' do
        freeze_time do
          sync_run.complete!
          expect(sync_run.completed_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'calls playlist.mark_tracks_synced! with snapshot_id' do
        allow(playlist).to receive(:mark_tracks_synced!)
        sync_run.complete!
        expect(playlist).to have_received(:mark_tracks_synced!).with(playlist.snapshot_id)
      end
    end

    describe '#fail!' do
      it 'sets error_message when provided' do
        sync_run.fail!('Spotify API authentication failed')
        expect(sync_run.error_message).to eq('Spotify API authentication failed')
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
