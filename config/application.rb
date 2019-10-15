# frozen_string_literal: true

require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "action_controller/railtie"
require 'active_job/railtie'
require 'active_record/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DorServices
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # If an object isn't found in DOR, return a 404
    config.action_dispatch.rescue_responses.merge!(
      "ActiveFedora::ObjectNotFoundError" => :not_found
    )

    # This makes sure our Postgres enums function are persisted to the schema
    config.active_record.schema_format = :sql
  end

  # see https://pdabrowski.com/blog/ruby-rescue-from-errors-with-grace
  class ContentDirNotFoundError < RuntimeError
    def self.===(exception)
      exception.class == RuntimeError && exception.message.match(/content dir not found for /)
    end
  end
end
