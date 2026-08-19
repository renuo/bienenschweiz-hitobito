# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

# Seeds the OAuth application and the API key (service token) that the KAS
# project uses to talk to this hitobito instance.
#
# By default random credentials are generated. To make a local KAS checkout work
# without copying values around, point KAS_PROJECT_PATH at it — the credentials
# are then read from its config/application.yml:
#
#   KAS_PROJECT_PATH=~/projects/vdrb-kas bundle exec rails db:seed wagon:seed

KAS_NAME = "KAS-LOCAL"
KAS_REDIRECT_URI = "http://localhost:3001/users/auth/hitobito/callback"
KAS_OAUTH_SCOPES = "openid email name with_roles"

# Reads the secrets from the KAS project's config/application.yml, which is a
# flat map of environment variables, optionally grouped by Rails environment.
def kas_credentials
  path = ENV["KAS_PROJECT_PATH"].presence
  return {} unless path

  application_yml = Pathname.new(File.expand_path(path)).join("config", "application.yml")
  unless application_yml.exist?
    raise "KAS_PROJECT_PATH is set but #{application_yml} does not exist"
  end

  config = YAML.safe_load(application_yml.read, aliases: true) || {}
  config.merge(config[Rails.env] || {})
end

credentials = kas_credentials
root = Group.root

def adopted(record, name)
  return record unless record && record.name != name

  puts "Reusing existing #{record.class.name.demodulize} #{record.name.inspect} as #{name.inspect}"
  record
end

# uid and token are unique, so an existing record holding the credentials we are
# about to apply has to be reused — it may predate this seed or carry a name from
# an earlier run. Only then fall back to looking the record up by its name.
application =
  adopted(credentials["HITOBITO_OAUTH_ID"] &&
    Oauth::Application.find_by(uid: credentials["HITOBITO_OAUTH_ID"]), KAS_NAME) ||
  Oauth::Application.find_by(name: KAS_NAME) ||
  Oauth::Application.new

application.name = KAS_NAME
application.redirect_uri = KAS_REDIRECT_URI
application.scopes = KAS_OAUTH_SCOPES
application.confidential = true
# Doorkeeper only generates uid and secret when they are blank.
application.uid = credentials["HITOBITO_OAUTH_ID"] if credentials["HITOBITO_OAUTH_ID"]
application.secret = credentials["HITOBITO_OAUTH_SECRET"] if credentials["HITOBITO_OAUTH_SECRET"]
application.save!

# ServiceToken names are unique per layer regardless of case, so the lookup by
# name has to be case insensitive as well.
service_token =
  adopted(credentials["HITOBITO_API_KEY"] &&
    ServiceToken.find_by(token: credentials["HITOBITO_API_KEY"]), KAS_NAME) ||
  ServiceToken.where(layer: root).find_by("LOWER(name) = ?", KAS_NAME.downcase) ||
  ServiceToken.new

service_token.name = KAS_NAME
service_token.layer = root
service_token.description = "API key for the KAS project"
service_token.permission = "layer_and_below_full"
service_token.people = true
service_token.groups = true
service_token.events = true
service_token.event_participations = true
service_token.save!

# ServiceToken generates a random token in a before_validation on: :create hook,
# so a given key can only be applied once the record exists.
if credentials["HITOBITO_API_KEY"]
  service_token.update!(token: credentials["HITOBITO_API_KEY"])
end

puts "KAS OAuth application: uid=#{application.uid} secret=#{application.secret}"
puts "KAS API key: #{service_token.token}"
