# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :spotify_id, null: false, index: { unique: true }
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.string :spotify_display_name
      t.string :spotify_email

      t.timestamps
    end
  end
end
