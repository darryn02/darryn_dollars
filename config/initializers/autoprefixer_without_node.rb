# Autoprefixer shells out to the `node` binary, so a machine without a working
# one cannot compile assets at all - which takes `rails s` down with it, along
# with every spec that renders a layout.
#
# That is not hypothetical. Homebrew moved Intel macOS to Tier 3 and stopped
# bottling node, openssl@3 and simdjson for it; building those from source
# needs a newer Xcode than the hardware can run. A developer machine here can
# quite reasonably have no node on it at all.
#
# Production is never affected - the Heroku buildpack provides node, and this
# file returns before doing anything there. The cost locally is CSS without
# vendor prefixes, which is invisible in a modern browser and changes nothing
# about what ships.
return if Rails.env.production?
return unless Rails.application.config.respond_to?(:assets)

module AutoprefixerWithoutNode
  # A broken node is worse than a missing one: the install that used to be here
  # was on PATH but aborted on a dyld error, so the file existing proves
  # nothing. Run it and see.
  def self.node_works?
    system("node", "--version", out: File::NULL, err: File::NULL) || false
  rescue SystemCallError
    false
  end
end

unless AutoprefixerWithoutNode.node_works?
  Rails.application.config.assets.configure do |env|
    require "autoprefixer-rails"
    # The gem's own removal API, rather than reaching into how it processes.
    AutoprefixerRails::Sprockets.uninstall(env)
  end

  Rails.logger&.info("[assets] no working `node` on PATH - compiling CSS without autoprefixer")
end
