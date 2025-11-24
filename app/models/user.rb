# frozen_string_literal: true

class User < ApplicationRecord
  has_many :playlists, dependent: :destroy
end
