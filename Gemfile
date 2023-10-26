source "https://rubygems.org"

ruby "3.2.1"

gem "autoprefixer-rails"
gem "bootstrap"
gem "delayed_job_active_record"
gem "devise"
gem "flutie"
gem 'haml-rails'
gem "honeybadger"
gem "importmap-rails"
gem "jquery-rails"
gem 'kaminari'
gem 'nokogiri'
gem "normalize-rails"
gem "pg"
gem "phony_rails"
gem "puma"
gem "rack-canonical-host"
gem "rails", "~> 7.0.0"
gem "reform-rails"
gem "recipient_interceptor"
gem "sassc-rails"
gem "simple_form"
gem "sprockets"
gem 'mini_racer'
gem 'execjs'
gem "title"
gem 'twilio-ruby'
gem "uglifier"
gem 'watir'
gem 'webdrivers', '~> 5.0', require: false

group :development do
  gem "listen"
  gem "spring"
  gem "spring-commands-rspec"
  gem "web-console"
end

group :development, :test do
  gem "awesome_print"
  gem "bullet"
  gem "bundler-audit", require: false
  gem "dotenv-rails"
  gem "factory_bot"
  gem "pry-byebug"
  gem "pry-rails"
  gem "rspec-rails"
  gem "rspec-support", '3.12.0'
end

group :development, :staging do
  gem "rack-mini-profiler", require: false
end

group :test do
  gem "capybara-selenium"
  gem "database_cleaner"
  gem "formulaic"
  gem "launchy"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "timecop"
  gem "webmock"
end

group :staging, :production do
  gem "rack-timeout"
end

gem 'high_voltage'
gem 'refills', group: [:development, :test]
