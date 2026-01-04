# frozen_string_literal: true

module Tracks
  class SyncRunJob < ApplicationJob
    include SpotifyJobErrorHandling

    queue_as :default

    discard_on StandardError do |job, error|
      job.handle_job_failure(error)
    end

    attr_reader :sync_run

    def perform(sync_run_id, *)
      @sync_run = TrackSyncRun.find(sync_run_id)

      call(*)
    end

    def call
      raise NotImplementedError, "Subclasses must implement #call"
    end

    private

    def handle_job_failure(error)
      sync_run&.fail!(error.message)
    end
  end
end
