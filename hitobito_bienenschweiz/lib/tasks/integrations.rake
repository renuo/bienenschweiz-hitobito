# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# OAuth applications and service tokens of external integrations are not part of the
# MV import and would be wiped by it. Their definitions live in the INTEGRATIONS_JSON
# env var of the target environment and are recreated with `integrations:restore`.
namespace :integrations do
  desc "Print OAuth applications and service tokens as JSON for INTEGRATIONS_JSON"
  task dump: :environment do
    # Intentionally self-contained: the block can be pasted into a rails console
    # of an environment that does not have this task deployed yet.
    timestamps = %w[id created_at updated_at]
    puts JSON.generate(
      oauth_applications: Oauth::Application.includes(:cors_origins).order(:id).map do |app|
        app.attributes.except(*timestamps)
          .merge("cors_origins" => app.cors_origins.map(&:origin))
      end,
      service_tokens: ServiceToken.includes(:layer, :cors_origins).order(:id).map do |token|
        token.attributes.except(*timestamps, "layer_group_id", "last_access")
          .merge("layer_group_code" => token.layer.code,
            "layer_group_name" => token.layer.name,
            "cors_origins" => token.cors_origins.map(&:origin))
      end
    )
  end

  desc "Recreate OAuth applications and service tokens from INTEGRATIONS_JSON"
  task restore: :environment do
    json = ENV["INTEGRATIONS_JSON"]
    if json.blank?
      puts "INTEGRATIONS_JSON is not set, nothing to restore."
    else
      Bienenschweiz::IntegrationsRestore.new(json).run
    end
  end
end
