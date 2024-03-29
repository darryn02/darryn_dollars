require Rails.root.join("config/smtp")
Rails.application.configure do
  config.cache_classes = false
  config.eager_load = false
  config.consider_all_requests_local = true
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => 'public, max-age=172800'
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end
  config.action_mailer.raise_delivery_errors = true
  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.rails_logger = true
  end
  config.action_mailer.delivery_method = :file
  config.action_mailer.perform_caching = false
  config.action_mailer.perform_deliveries = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = SMTP_SETTINGS
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.assets.debug = true
  config.assets.quiet = true
  config.i18n.raise_on_missing_translations = true
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  config.action_mailer.default_url_options = { host: "localhost:3000" }
  config.sass.inline_source_maps = true
  config.hosts << "fd62-73-167-77-116.ngrok-free.app"
end
