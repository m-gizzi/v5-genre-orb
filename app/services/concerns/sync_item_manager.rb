# frozen_string_literal: true

module SyncItemManager
  private

  def sync_item_class
    raise NotImplementedError, "#{self.class} must implement #sync_item_class"
  end

  def sync_item_foreign_key
    raise NotImplementedError, "#{self.class} must implement #sync_item_foreign_key"
  end

  def item_foreign_key
    raise NotImplementedError, "#{self.class} must implement #item_foreign_key"
  end

  def facade_method_name
    raise NotImplementedError, "#{self.class} must implement #facade_method_name"
  end

  def facade_arguments(limit:, offset:)
    raise NotImplementedError, "#{self.class} must implement #facade_arguments"
  end

  def fetch_and_persist(limit:, offset:)
    FetchAndPersistFacade.public_send(
      facade_method_name,
      **facade_arguments(limit: limit, offset: offset)
    )
  end

  def create_sync_items(item_ids)
    item_ids.each do |item_id|
      sync_item_class.find_or_create_by!(
        sync_item_foreign_key => sync_run.id,
        item_foreign_key => item_id
      )
    end
  end
end
