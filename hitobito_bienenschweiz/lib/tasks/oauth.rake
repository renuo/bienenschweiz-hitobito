# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

namespace :oauth do
  desc "Print a curl command fetching /oauth/profile for a person " \
       "(args: person_id, scope=with_roles)"
  task :profile_curl, [:person_id, :scope] => :environment do |_t, args|
    person = Person.find(args.fetch(:person_id))
    scope = args[:scope].presence || "with_roles"

    application = Oauth::Application.find_or_create_by!(name: "Profile debugging (rake)") do |app|
      app.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
      app.scopes = "email name with_roles"
    end
    token = Oauth::AccessToken.create!(
      application:,
      resource_owner_id: person.id,
      scopes: application.scopes,
      expires_in: 1.hour.to_i
    )

    url = "#{Settings.application.protocol}://#{Settings.application.hostname}/oauth/profile"
    puts %(curl -s -H "Authorization: Bearer #{token.token}" -H "X-Scope: #{scope}" #{url})
  end
end
