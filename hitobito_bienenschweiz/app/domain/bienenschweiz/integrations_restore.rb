# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Recreates OAuth applications and service tokens (API keys) from the JSON produced by
# `rake integrations:dump`, so external integrations survive a full MV re-import.
# Records are matched by uid / token, so running it repeatedly is safe.
module Bienenschweiz
  class IntegrationsRestore
    def initialize(json)
      @config = JSON.parse(json)
    end

    def run
      ActiveRecord::Base.transaction do
        Array(@config["oauth_applications"]).each { |attrs| restore_oauth_application(attrs) }
        Array(@config["service_tokens"]).each { |attrs| restore_service_token(attrs) }
      end
    end

    private

    def restore_oauth_application(attrs)
      app = Oauth::Application.find_or_initialize_by(uid: attrs.fetch("uid"))
      app.assign_attributes(attrs.except("cors_origins"))
      app.save!
      sync_cors_origins(app, attrs["cors_origins"])
      log("OAuth application", app)
    end

    def restore_service_token(attrs)
      token = ServiceToken.find_or_initialize_by(token: attrs.fetch("token"))
      token.assign_attributes(attrs.except("cors_origins", "layer_group_code", "layer_group_name"))
      token.layer = find_layer(attrs)
      token.save!
      # ServiceToken generates a fresh token on create, put the original one back
      token.update_column(:token, attrs["token"]) if token.token != attrs["token"]
      sync_cors_origins(token, attrs["cors_origins"])
      log("Service token", token)
    end

    def find_layer(attrs)
      layers = ::Group.where("groups.id = groups.layer_group_id")
      layer = if attrs["layer_group_code"].present?
        layers.find_by(code: attrs["layer_group_code"])
      else
        layers.find_by(name: attrs["layer_group_name"])
      end
      layer || raise(ActiveRecord::RecordNotFound,
        "Layer not found (code: #{attrs["layer_group_code"].inspect}, " \
        "name: #{attrs["layer_group_name"].inspect})")
    end

    def sync_cors_origins(record, origins)
      origins = Array(origins)
      record.cors_origins.where.not(origin: origins).delete_all
      (origins - record.cors_origins.pluck(:origin)).each do |origin|
        record.cors_origins.create!(origin:)
      end
    end

    def log(kind, record)
      Rails.logger.info("Restored #{kind} '#{record.name}' (id #{record.id})")
      puts "Restored #{kind} '#{record.name}' (id #{record.id})" # rubocop:disable Rails/Output
    end
  end
end
