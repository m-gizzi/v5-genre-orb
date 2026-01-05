# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaylistTrackSync::CoordinatorJob do
  let(:playlist) { create(:playlist) }
  let(:sync_run) { create(:track_sync_run, playlist: playlist, status: :pending) }
  let(:service) { instance_double(PlaylistTrackSync::CoordinateTrackSyncService) }

  describe '#perform' do
    before do
      allow(PlaylistTrackSync::CoordinateTrackSyncService).to receive(:new)
        .with(sync_run: sync_run).and_return(service)
      allow(service).to receive(:call)
    end

    it 'calls CoordinateTrackSyncService with sync_run' do
      described_class.perform_now(sync_run.id)
      expect(service).to have_received(:call)
    end

    it 'initializes service with sync_run' do
      described_class.perform_now(sync_run.id)
      expect(PlaylistTrackSync::CoordinateTrackSyncService).to have_received(:new).with(sync_run: sync_run)
    end
  end
end
