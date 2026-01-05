# frozen_string_literal: true

class SyncRunJob < ApplicationJob
  include SpotifyJobErrorHandling

  queue_as :default

  discard_on StandardError do |job, error|
    job.handle_job_failure(error)
  end

  attr_reader :sync_run

  def perform(sync_run_id, *)
    @sync_run = sync_run_class.find(sync_run_id)
    call(*)
  end

  def call(*)
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  private

  def sync_run_class
    raise NotImplementedError, "#{self.class} must implement #sync_run_class"
  end

  def handle_job_failure(error)
    sync_run&.fail!(error.message)
  end
end
