# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Track sync flow' do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:playlist) do
    create(:playlist, user: user, snapshot_id: 'snapshot_123').tap do |p|
      # Ensure raw_data snapshot_id matches the column value
      p.update!(raw_data: p.raw_data.merge('snapshot_id' => 'snapshot_123'))
    end
  end
  let(:track_client) { instance_double(Spotify::TrackClient) }
  let(:playlist_client) { instance_double(Spotify::PlaylistClient) }

  before do
    allow(Spotify::TrackClient).to receive(:for_user).with(user).and_return(track_client)
    allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(playlist_client)
    allow(playlist_client).to receive(:fetch_playlist).and_return(playlist.raw_data)
  end

  describe 'full sync from start to finish' do
    let(:first_tracks_batch) { generate_track_items(count: 100, starting_index: 0) }
    let(:second_tracks_batch) { generate_track_items(count: 50, starting_index: 100) }

    before do
      allow(track_client).to receive(:fetch_playlist_tracks)
        .with(playlist, limit: 100, offset: 0)
        .and_return(build_spotify_tracks_response(track_items: first_tracks_batch, total: 150, next_url: 'next_url'))
      allow(track_client).to receive(:fetch_playlist_tracks)
        .with(playlist, limit: 100, offset: 100)
        .and_return(build_spotify_tracks_response(track_items: second_tracks_batch, total: 150, offset: 100, prev_url: 'prev_url'))
    end

    it 'completes full sync from start to finish' do
      sync_run = nil

      perform_enqueued_jobs do
        sync_run = PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(sync_run.reload).to be_completed
      expect(sync_run.completed_at).not_to be_nil
    end

    it 'creates all tracks from Spotify' do
      perform_enqueued_jobs do
        PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(Track.count).to eq(150)
    end

    it 'creates all artists from tracks' do
      perform_enqueued_jobs do
        PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(Artist.count).to eq(150)
    end

    it 'creates all track-artist associations' do
      perform_enqueued_jobs do
        PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(TrackArtist.count).to eq(150)
    end

    it 'creates all playlist-track associations' do
      perform_enqueued_jobs do
        PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(PlaylistTrack.where(playlist: playlist).count).to eq(150)
    end

    it 'sets correct track attributes' do
      perform_enqueued_jobs do
        PlaylistTrackSync::StartSyncService.call(playlist)
      end

      track = Track.find_by(spotify_id: 'track0')
      expect(track.name).to eq('Track 0')
      expect(track.duration_ms).to eq(180_000)
    end

    it 'creates sync items for all tracks' do
      sync_run = nil

      perform_enqueued_jobs do
        sync_run = PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(sync_run.reload.track_sync_items.count).to eq(150)
    end

    it 'updates progress counters correctly' do
      sync_run = nil

      perform_enqueued_jobs do
        sync_run = PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(sync_run.reload.tracks_processed).to eq(150)
      expect(sync_run.reload.artists_processed).to eq(150)
    end

    it 'updates playlist last_track_synced_at' do
      freeze_time do
        perform_enqueued_jobs do
          PlaylistTrackSync::StartSyncService.call(playlist)
        end

        expect(playlist.reload.last_track_synced_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'updates playlist last_track_sync_snapshot_id' do
      perform_enqueued_jobs do
        PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(playlist.reload.last_track_sync_snapshot_id).to eq('snapshot_123')
    end

    context 'when some tracks were removed from playlist' do
      let!(:existing_track) { create(:track, spotify_id: 'old_track') }
      let!(:playlist_track) { create(:playlist_track, playlist: playlist, track: existing_track) }

      before do
        # This track exists in the playlist but won't be in the new sync
      end

      it 'removes playlist_tracks not found in Spotify' do
        perform_enqueued_jobs do
          PlaylistTrackSync::StartSyncService.call(playlist)
        end

        expect(PlaylistTrack.exists?(playlist_track.id)).to be false
      end

      it 'keeps tracks that still exist in playlist' do
        perform_enqueued_jobs do
          PlaylistTrackSync::StartSyncService.call(playlist)
        end

        track0_playlist_track = PlaylistTrack.find_by(playlist: playlist, track: Track.find_by(spotify_id: 'track0'))
        expect(track0_playlist_track).to be_present
      end
    end

    context 'when playlist has fewer than 100 tracks' do
      let(:small_tracks_batch) { generate_track_items(count: 25) }

      before do
        allow(track_client).to receive(:fetch_playlist_tracks)
          .with(playlist, limit: 100, offset: 0)
          .and_return(build_spotify_tracks_response(track_items: small_tracks_batch, total: 25))
      end

      it 'completes sync successfully' do
        sync_run = nil

        perform_enqueued_jobs do
          sync_run = PlaylistTrackSync::StartSyncService.call(playlist)
        end

        expect(sync_run.reload).to be_completed
        expect(Track.count).to eq(25)
      end
    end

    context 'when playlist has no tracks' do
      before do
        allow(track_client).to receive(:fetch_playlist_tracks)
          .with(playlist, limit: 100, offset: 0)
          .and_return(build_spotify_tracks_response(track_items: [], total: 0))
      end

      it 'completes sync successfully' do
        sync_run = nil

        perform_enqueued_jobs do
          sync_run = PlaylistTrackSync::StartSyncService.call(playlist)
        end

        expect(sync_run.reload).to be_completed
        expect(Track.count).to eq(0)
      end
    end

    context 'when tracks already exist' do
      let!(:existing_track) { create(:track, spotify_id: 'track0', name: 'Old Name') }

      before do
        allow(track_client).to receive(:fetch_playlist_tracks)
          .with(playlist, limit: 100, offset: 0)
          .and_return(build_spotify_tracks_response(track_items: first_tracks_batch, total: 150, next_url: 'next_url'))
        allow(track_client).to receive(:fetch_playlist_tracks)
          .with(playlist, limit: 100, offset: 100)
          .and_return(build_spotify_tracks_response(track_items: second_tracks_batch, total: 150, offset: 100, prev_url: 'prev_url'))
      end

      it 'does not create duplicate tracks' do
        perform_enqueued_jobs do
          PlaylistTrackSync::StartSyncService.call(playlist)
        end

        expect(Track.count).to eq(150)
      end

      it 'updates existing tracks' do
        perform_enqueued_jobs do
          PlaylistTrackSync::StartSyncService.call(playlist)
        end

        expect(existing_track.reload.name).to eq('Track 0')
      end
    end
  end

  context 'when playlist snapshot has not changed' do
    before do
      # Update both the snapshot_id column and raw_data to match
      current_snapshot = playlist.snapshot_id
      playlist.update!(
        last_track_sync_snapshot_id: current_snapshot,
        raw_data: playlist.raw_data.merge('snapshot_id' => current_snapshot)
      )
    end

    it 'does not create a new sync' do
      result = PlaylistTrackSync::StartSyncService.call(playlist)

      expect(result).to be_nil
      expect(TrackSyncRun.count).to eq(0)
    end
  end

  context 'when there is already an in-progress sync' do
    let!(:existing_sync) { create(:track_sync_run, playlist: playlist, status: :processing_batches) }

    it 'does not create a new sync' do
      result = nil

      perform_enqueued_jobs do
        result = PlaylistTrackSync::StartSyncService.call(playlist)
      end

      expect(result).to eq(existing_sync)
      expect(TrackSyncRun.count).to eq(1)
    end
  end
end
