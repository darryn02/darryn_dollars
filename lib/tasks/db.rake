namespace :db do
  desc 'Reset the database by doing a drop/create/migrate/dev:prime (rather than just loading schema.rb)'
  task recreate: [:drop, :create, :migrate, 'dev:prime']
end
