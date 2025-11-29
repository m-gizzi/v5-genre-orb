# frozen_string_literal: true

class Playlist < ApplicationRecord
  belongs_to :user

  validates :spotify_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :raw_data, presence: true
end
