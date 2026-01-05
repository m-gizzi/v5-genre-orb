# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaylistTrackSync::CleanupRemovedJob do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user, snapshot_id: 'snapshot_123') }
  let(:sync_run) { create(:track_sync_run, playlist: playlist, status: :archiving, started_at: Time.current) }

  describe '#perform' do
    context 'when all tracks are still in playlist' do
      let!(:track1) { create(:track) }
      let!(:track2) { create(:track) }
      let!(:playlist_track1) { create(:playlist_track, playlist: playlist, track: track1) }
      let!(:playlist_track2) { create(:playlist_track, playlist: playlist, track: track2) }

      before do
        create(:track_sync_item, track_sync_run: sync_run, track: track1)
        create(:track_sync_item, track_sync_run: sync_run, track: track2)
      end

      it 'does not remove any playlist tracks' do
        expect do
          described_class.perform_now(sync_run.id)
        end.not_to change(PlaylistTrack, :count)
      end

      it 'marks sync_run as completed' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload).to be_completed
      end

      it 'sets completed_at timestamp' do
        freeze_time do
          described_class.perform_now(sync_run.id)
          expect(sync_run.reload.completed_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'calls playlist.mark_tracks_synced!' do
        described_class.perform_now(sync_run.id)
        expect(playlist.reload.last_track_sync_snapshot_id).to eq('snapshot_123')
        expect(playlist.last_track_synced_at).not_to be_nil
      end
    end

    context 'when some tracks were removed from playlist' do
      let!(:synced_track) { create(:track) }
      let!(:removed_track) { create(:track) }
      let!(:synced_playlist_track) { create(:playlist_track, playlist: playlist, track: synced_track) }
      let!(:removed_playlist_track) { create(:playlist_track, playlist: playlist, track: removed_track) }

      before do
        # Only the synced_track was in the latest sync
        create(:track_sync_item, track_sync_run: sync_run, track: synced_track)
      end

      it 'removes playlist_tracks for tracks not in sync' do
        expect do
          described_class.perform_now(sync_run.id)
        end.to change(PlaylistTrack, :count).by(-1)
      end

      it 'removes the specific removed playlist_track' do
        described_class.perform_now(sync_run.id)
        expect(PlaylistTrack.exists?(removed_playlist_track.id)).to be false
      end

      it 'keeps playlist_tracks that were synced' do
        described_class.perform_now(sync_run.id)
        expect(PlaylistTrack.exists?(synced_playlist_track.id)).to be true
      end

      it 'marks sync_run as completed' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload).to be_completed
      end
    end

    context 'when other playlists have the same track' do
      let!(:track) { create(:track) }
      let!(:other_playlist) { create(:playlist, user: user) }
      let!(:playlist_track1) { create(:playlist_track, playlist: playlist, track: track) }
      let!(:playlist_track2) { create(:playlist_track, playlist: other_playlist, track: track) }

      before do
        # Track is not in this sync (removed from playlist)
      end

      it 'only removes the playlist_track for this playlist' do
        expect do
          described_class.perform_now(sync_run.id)
        end.to change(PlaylistTrack, :count).by(-1)
      end

      it 'keeps the track in other playlists' do
        described_class.perform_now(sync_run.id)
        expect(PlaylistTrack.exists?(playlist_track2.id)).to be true
      end

      it 'does not delete the track itself' do
        expect do
          described_class.perform_now(sync_run.id)
        end.not_to change(Track, :count)
      end
    end
  end
end
