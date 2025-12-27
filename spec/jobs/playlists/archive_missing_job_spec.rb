# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Playlists::ArchiveMissingJob do
  let(:user) { create(:user) }
  let(:sync_run) { create(:playlist_sync_run, user: user, status: :archiving, started_at: Time.current) }

  describe '#perform' do
    context 'when playlist is still in Spotify' do
      let!(:playlist) { create(:playlist, user: user, spotify_id: 'p1') }

      before do
        create(:playlist_sync_item, playlist_sync_run: sync_run, playlist: playlist)
      end

      it 'does not archive any playlists' do
        described_class.perform_now(sync_run.id)

        expect(playlist.reload.archived_at).to be_nil
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
    end

    context 'when some playlists are missing from Spotify' do
      let!(:synced_playlist) { create(:playlist, user: user, spotify_id: 'p1') }
      let!(:missing_playlist) { create(:playlist, user: user, spotify_id: 'p2', archived_at: nil) }

      before do
        create(:playlist_sync_item, playlist_sync_run: sync_run, playlist: synced_playlist)
      end

      it 'archives playlists not in sync' do
        freeze_time do
          described_class.perform_now(sync_run.id)

          expect(missing_playlist.reload.archived_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'does not archive playlists that were synced' do
        described_class.perform_now(sync_run.id)
        expect(synced_playlist.reload.archived_at).to be_nil
      end

      it 'marks sync_run as completed' do
        described_class.perform_now(sync_run.id)
        expect(sync_run.reload).to be_completed
      end
    end

    context 'when playlist is already archived' do
      let!(:synced_playlist) { create(:playlist, user: user, spotify_id: 'p1') }
      let!(:already_archived) { create(:playlist, user: user, spotify_id: 'p2', archived_at: 1.day.ago) }

      before do
        create(:playlist_sync_item, playlist_sync_run: sync_run, playlist: synced_playlist)
      end

      it 'does not update already archived playlists' do
        original_archived_at = already_archived.archived_at
        described_class.perform_now(sync_run.id)

        expect(already_archived.reload.archived_at).to be_within(1.second).of(original_archived_at)
      end
    end
  end
end
