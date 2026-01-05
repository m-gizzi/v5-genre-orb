# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spotify::TrackRepository do
  let(:user) { create(:user) }
  let(:playlist) { create(:playlist, user: user) }
  let(:repository) { described_class.new(playlist: playlist) }

  describe '#process_batch' do
    let(:raw_tracks) do
      [
        {
          'track' => {
            'id' => 'track1',
            'name' => 'Track 1',
            'duration_ms' => 180_000,
            'disc_number' => 1,
            'track_number' => 1,
            'explicit' => false,
            'is_local' => false,
            'popularity' => 75,
            'preview_url' => 'https://p.scdn.co/mp3-preview/test1',
            'external_ids' => { 'isrc' => 'USUM71234561' },
            'artists' => [
              { 'id' => 'artist1', 'name' => 'Artist 1', 'uri' => 'spotify:artist:artist1' },
              { 'id' => 'artist2', 'name' => 'Artist 2', 'uri' => 'spotify:artist:artist2' }
            ],
            'album' => { 'name' => 'Album 1', 'images' => [{ 'url' => 'https://example.com/1.jpg' }] }
          },
          'added_at' => '2024-01-01T12:00:00Z',
          'added_by' => { 'id' => 'user1' }
        },
        {
          'track' => {
            'id' => 'track2',
            'name' => 'Track 2',
            'duration_ms' => 200_000,
            'disc_number' => 1,
            'track_number' => 2,
            'explicit' => true,
            'is_local' => false,
            'popularity' => 80,
            'preview_url' => 'https://p.scdn.co/mp3-preview/test2',
            'external_ids' => { 'isrc' => 'USUM71234562' },
            'artists' => [
              { 'id' => 'artist1', 'name' => 'Artist 1', 'uri' => 'spotify:artist:artist1' }
            ],
            'album' => { 'name' => 'Album 2', 'images' => [] }
          },
          'added_at' => '2024-01-02T12:00:00Z',
          'added_by' => { 'id' => 'user1' }
        }
      ]
    end

    it 'creates Track records' do
      expect { repository.process_batch(raw_tracks) }.to change(Track, :count).by(2)
    end

    it 'creates Artist records' do
      expect { repository.process_batch(raw_tracks) }.to change(Artist, :count).by(2)
    end

    it 'creates TrackArtist associations' do
      expect { repository.process_batch(raw_tracks) }.to change(TrackArtist, :count).by(3)
    end

    it 'creates PlaylistTrack associations' do
      expect { repository.process_batch(raw_tracks) }.to change(PlaylistTrack, :count).by(2)
    end

    it 'returns item_ids array' do
      result = repository.process_batch(raw_tracks)
      expect(result[:item_ids]).to be_an(Array)
      expect(result[:item_ids].length).to eq(2)
    end

    it 'returns counts hash' do
      result = repository.process_batch(raw_tracks)
      expect(result[:counts]).to include(
        tracks_processed: 2,
        artists_processed: 3
      )
    end

    it 'stores complete track data in raw_data' do
      repository.process_batch(raw_tracks)
      track = Track.find_by(spotify_id: 'track1')
      expect(track.raw_data['name']).to eq('Track 1')
      expect(track.raw_data['album']['name']).to eq('Album 1')
    end

    it 'stores complete artist data in raw_data' do
      repository.process_batch(raw_tracks)
      artist = Artist.find_by(spotify_id: 'artist1')
      expect(artist.raw_data['name']).to eq('Artist 1')
    end

    context 'when track already exists' do
      let!(:existing_track) { create(:track, spotify_id: 'track1', name: 'Old Name') }

      it 'updates existing track' do
        repository.process_batch(raw_tracks)
        expect(existing_track.reload.name).to eq('Track 1')
      end

      it 'does not create duplicate tracks' do
        expect { repository.process_batch(raw_tracks) }.to change(Track, :count).by(1)
      end

      it 'replaces artist associations for existing track' do
        old_artist = create(:artist, spotify_id: 'old_artist')
        create(:track_artist, track: existing_track, artist: old_artist)

        repository.process_batch(raw_tracks)

        expect(existing_track.reload.artists.pluck(:spotify_id)).to match_array(['artist1', 'artist2'])
        expect(existing_track.artists).not_to include(old_artist)
      end
    end

    context 'when artist already exists' do
      let!(:existing_artist) { create(:artist, spotify_id: 'artist1', name: 'Old Artist Name') }

      it 'does not create duplicate artists' do
        expect { repository.process_batch(raw_tracks) }.to change(Artist, :count).by(1)
      end

      it 'does not update existing artist name' do
        repository.process_batch(raw_tracks)
        expect(existing_artist.reload.name).to eq('Old Artist Name')
      end
    end

    context 'when playlist track association already exists' do
      let!(:track) { create(:track, spotify_id: 'track1') }
      let!(:playlist_track) do
        create(:playlist_track,
               playlist: playlist,
               track: track,
               added_at: 1.week.ago)
      end

      it 'updates the existing playlist_track' do
        repository.process_batch(raw_tracks)
        expect(playlist_track.reload.added_at).to be_within(1.second).of(Time.zone.parse('2024-01-01T12:00:00Z'))
      end

      it 'does not create duplicate playlist_tracks' do
        expect { repository.process_batch(raw_tracks) }.to change(PlaylistTrack, :count).by(1)
      end
    end

    context 'when track data is nil' do
      let(:raw_tracks) do
        [
          { 'track' => nil },
          build_spotify_track_item(track_id: 'track2', track_name: 'Track 2')
        ]
      end

      it 'skips nil tracks' do
        expect { repository.process_batch(raw_tracks) }.to change(Track, :count).by(1)
      end

      it 'only processes valid tracks' do
        result = repository.process_batch(raw_tracks)
        expect(result[:counts][:tracks_processed]).to eq(1)
      end
    end

    context 'when track has multiple artists' do
      it 'creates all artist associations in order' do
        repository.process_batch(raw_tracks)
        track = Track.find_by(spotify_id: 'track1')
        expect(track.artists.pluck(:spotify_id)).to eq(['artist1', 'artist2'])
      end
    end

    context 'when track has no artists' do
      let(:raw_tracks) do
        [build_spotify_track_item(track_id: 'track1', track_name: 'Track 1', artists: [])]
      end

      it 'creates track without artists' do
        expect { repository.process_batch(raw_tracks) }.to change(Track, :count).by(1)
      end

      it 'does not create artist records' do
        expect { repository.process_batch(raw_tracks) }.not_to change(Artist, :count)
      end
    end
  end
end
