RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  # A system spec drives a real browser against a Capybara server running in
  # another thread on a different database connection. Rows written inside an
  # uncommitted transaction do not exist as far as that connection is
  # concerned, so the browser loads an empty board and the example fails
  # hunting for markup the app was never given the data to render.
  #
  # Deletion commits, which costs some speed and buys a browser that can
  # actually see the fixture. The `js: true` branch below was written for a
  # driver that never arrived; system specs carry `type: :system`, not
  # `js: true`, so it never fired. Both are matched now - the tag still works
  # if anyone reaches for it.
  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :deletion
  end

  config.before(:each, js: true) do
    DatabaseCleaner.strategy = :deletion
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
