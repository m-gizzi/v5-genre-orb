# frozen_string_literal: true

class CreateRateLimitCooldowns < ActiveRecord::Migration[8.1]
  def change
    create_table :rate_limit_cooldowns do |t|
      t.string :endpoint, null: false
      t.datetime :expires_at, null: false
      t.integer :retry_after_seconds, null: false

      t.timestamps

      t.index :endpoint, unique: true, name: 'index_cooldowns_on_endpoint_unique'
      t.index :expires_at
    end
  end
end
