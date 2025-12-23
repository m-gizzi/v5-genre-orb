# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncUserPlaylistsService do
  describe '#call' do
    subject(:sync_playlists) { described_class.call(user) }

    let(:user) { create(:user) }
    let(:spotify_client) { instance_double(Spotify::PlaylistClient) }
    let(:playlist_data_1) do
      {
        spotify_id: 'spotify_pl_1',
        name: 'Playlist 1',
        description: 'First playlist',
        public: true,
        collaborative: false,
        owner: { id: user.spotify_id, display_name: user.spotify_display_name },
        snapshot_id: 'snap1',
        tracks_total: 10
      }
    end
    let(:playlist_data_2) do
      {
        spotify_id: 'spotify_pl_2',
        name: 'Playlist 2',
        description: nil,
        public: false,
        collaborative: true,
        owner: { id: user.spotify_id, display_name: user.spotify_display_name },
        snapshot_id: 'snap2',
        tracks_total: 5
      }
    end

    before do
      allow(Spotify::PlaylistClient).to receive(:for_user).with(user).and_return(spotify_client)
      allow(spotify_client).to receive(:fetch_all_user_playlists).and_return([playlist_data_1, playlist_data_2])
    end

    it 'creates new playlists' do
      expect { sync_playlists }.to change(user.playlists, :count).by(2)
    end

    it 'returns synced playlist records' do
      result = sync_playlists
      expect(result).to all(be_a(Playlist))
      expect(result.map(&:spotify_id)).to match_array(['spotify_pl_1', 'spotify_pl_2'])
    end

    it 'stores playlist data correctly' do
      sync_playlists
      playlist = user.playlists.find_by(spotify_id: 'spotify_pl_1')

      expect(playlist.name).to eq('Playlist 1')
      expect(playlist.description).to eq('First playlist')
      expect(playlist.raw_data).to include(
        'spotify_id' => 'spotify_pl_1',
        'tracks_total' => 10
      )
    end

    context 'when playlist already exists' do
      let!(:existing_playlist) do
        create(:playlist, user: user, spotify_id: 'spotify_pl_1', name: 'Old Name', description: 'Old Desc')
      end

      it 'updates the existing playlist' do
        expect { sync_playlists }.to change(user.playlists, :count).by(1)
      end

      it 'updates playlist attributes' do
        sync_playlists
        existing_playlist.reload

        expect(existing_playlist.name).to eq('Playlist 1')
        expect(existing_playlist.description).to eq('First playlist')
      end

      it 'updates raw_data' do
        sync_playlists
        existing_playlist.reload

        expect(existing_playlist.raw_data).to include(
          'snapshot_id' => 'snap1',
          'tracks_total' => 10
        )
      end
    end

    context 'when previously archived playlist reappears' do
      let!(:archived_playlist) do
        create(:playlist, :archived, user: user, spotify_id: 'spotify_pl_1')
      end

      it 'unarchives the playlist' do
        sync_playlists
        expect(archived_playlist.reload.archived_at).to be_nil
      end

      it 'updates the playlist data' do
        sync_playlists
        archived_playlist.reload

        expect(archived_playlist.name).to eq('Playlist 1')
        expect(archived_playlist.description).to eq('First playlist')
      end
    end

    context 'when user has playlists not in Spotify response' do
      let!(:playlist_to_archive) { create(:playlist, user: user, spotify_id: 'old_playlist') }

      it 'archives playlists not returned by Spotify' do
        sync_playlists
        expect(playlist_to_archive.reload.archived_at).not_to be_nil
      end

      it 'does not delete the playlist record' do
        expect { sync_playlists }.to change(Playlist, :count).by(2)
      end

      it 'does not re-archive already archived playlists' do
        already_archived = create(:playlist, :archived, user: user, spotify_id: 'already_archived')
        original_archived_at = already_archived.archived_at

        sync_playlists
        expect(already_archived.reload.archived_at).to eq(original_archived_at)
      end
    end

    context 'when Spotify returns empty playlist list' do
      before do
        allow(spotify_client).to receive(:fetch_all_user_playlists).and_return([])
      end

      let!(:existing_playlist) { create(:playlist, user: user) }

      it 'archives all existing active playlists' do
        sync_playlists
        expect(existing_playlist.reload.archived_at).not_to be_nil
      end

      it 'does not create any playlists' do
        expect { sync_playlists }.to change(user.playlists.active, :count).by(-1)
      end
    end

    context 'when API call fails' do
      before do
        allow(spotify_client).to receive(:fetch_all_user_playlists)
          .and_raise(Spotify::Errors::AuthenticationError, 'Token expired')
      end

      it 'raises the error without saving any changes' do
        expect { sync_playlists }.to raise_error(Spotify::Errors::AuthenticationError)
      end

      it 'does not create any playlists' do
        expect do
          sync_playlists
        rescue Spotify::Errors::AuthenticationError
          # Expected
        end.not_to change(Playlist, :count)
      end
    end

    context 'when database save fails' do
      before do
        allow_any_instance_of(Playlist).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'rolls back the transaction' do
        expect do
          sync_playlists
        rescue ActiveRecord::RecordInvalid
          # Expected
        end.not_to change(Playlist, :count)
      end
    end

    context 'with multiple users' do
      let(:other_user) { create(:user) }
      let!(:other_user_playlist) { create(:playlist, user: other_user, spotify_id: 'other_pl') }

      it 'only syncs playlists for the specified user' do
        sync_playlists
        expect(other_user_playlist.reload.archived_at).to be_nil
      end

      it 'does not affect other users playlists' do
        expect { sync_playlists }.not_to change { other_user.playlists.count }
      end
    end
  end
end
