# frozen_string_literal: true

module Playlists
  class StartSyncService < ApplicationService
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def call
      existing = PlaylistSyncRun.in_progress_for_user(user)
      return existing if existing

      sync_run = PlaylistSyncRun.create!(user: user, status: :pending)
      Playlists::CoordinatorJob.perform_later(sync_run.id)
      sync_run
    rescue ActiveRecord::RecordNotUnique
      PlaylistSyncRun.in_progress_for_user(user)
    end
  end
end
