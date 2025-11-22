# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    FactoryBot.lint if Rails.env.test?
  end
end
