# frozen_string_literal: true

module UserPlaylistSync
  class StartSyncService < ApplicationService
    attr_reader :user

    def initialize(user)
      @user = user
    end

    def call
      existing = find_in_progress_sync
      return existing if existing

      create_new_sync
    rescue ActiveRecord::RecordNotUnique
      find_in_progress_sync
    end

    private

    def find_in_progress_sync
      PlaylistSyncRun.in_progress_for_user(user)
    end

    def create_new_sync
      sync_run = PlaylistSyncRun.create!(user: user, status: :pending)
      UserPlaylistSync::CoordinatorJob.perform_later(sync_run.id)
      sync_run
    end
  end
end
