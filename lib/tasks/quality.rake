# frozen_string_literal: true

desc 'Run all checks (CI simulation)'
task ci: :environment do
  puts "\nRunning full CI suite...\n"

  puts "\n== Running RuboCop =="
  system('bundle exec rubocop') || abort

  puts "\n== Checking for code smells with Reek =="
  system('bundle exec reek') || abort

  puts "\n== Checking Rails best practices =="
  system('bundle exec rails_best_practices .') || abort

  puts "\n== Scanning for security vulnerabilities with Brakeman =="
  system('bin/brakeman --no-pager') || abort

  puts "\n== Checking for vulnerable gems =="
  system('bin/bundler-audit') || abort

  puts "\n== Running RSpec tests =="
  system('bundle exec rspec') || abort

  puts "\nAll checks passed! Ready to commit/push!"
end
