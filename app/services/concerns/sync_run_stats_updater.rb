# frozen_string_literal: true

module SyncRunStatsUpdater
  private

  def update_sync_run_stats(sync_run, stats)
    sync_run.with_lock do
      stats.each do |stat_name, count|
        sync_run.increment!(stat_name, count)
      end
    end
  end
end
