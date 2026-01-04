# frozen_string_literal: true

module Playlists
  class SyncRunJob < ApplicationJob
    include SpotifyJobErrorHandling

    discard_on StandardError do |job, error|
      job.handle_job_failure(error)
    end

    def perform(sync_run_id, *)
      @sync_run = PlaylistSyncRun.find(sync_run_id)

      call(*)
    end

    private

    attr_reader :sync_run

    def handle_job_failure(error)
      sync_run&.fail!(error.message)
    end
  end
end
