# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaylistTrackSync::FetchTrackBatchJob do
  let(:playlist) { create(:playlist) }
  let(:sync_run) { create(:track_sync_run, playlist: playlist, status: :processing_batches) }
  let(:service) { instance_double(PlaylistTrackSync::FetchTrackBatchService) }

  describe '#perform' do
    before do
      allow(PlaylistTrackSync::FetchTrackBatchService).to receive(:new)
        .with(sync_run: sync_run, offset: 100, limit: 100).and_return(service)
      allow(service).to receive(:call)
    end

    it 'calls FetchTrackBatchService with correct parameters' do
      described_class.perform_now(sync_run.id, 100, 100)
      expect(service).to have_received(:call)
    end

    it 'initializes service with sync_run, offset, and limit' do
      described_class.perform_now(sync_run.id, 100, 100)
      expect(PlaylistTrackSync::FetchTrackBatchService).to have_received(:new)
        .with(sync_run: sync_run, offset: 100, limit: 100)
    end
  end
end
