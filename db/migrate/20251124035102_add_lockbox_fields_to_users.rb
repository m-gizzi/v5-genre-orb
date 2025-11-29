# frozen_string_literal: true

class AddLockboxFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      change_table :users, bulk: true do |t|
        t.text :access_token_ciphertext
        t.text :refresh_token_ciphertext
        t.remove :access_token, type: :text
        t.remove :refresh_token, type: :text
      end
    end
  end
end
