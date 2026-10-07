# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

require "spec_helper"

describe "GET oauth/profile", type: :request do
  let(:user) { Fabricate(:magazine_subscriber) }
  let(:token) do
    Fabricate(:access_token, application: Fabricate(:application),
      scopes: "email name with_roles", resource_owner_id: user.id)
  end

  def profile(scope)
    get "/oauth/profile", headers: {Authorization: "Bearer #{token.token}", "X-Scope": scope}
    expect(response).to have_http_status(:ok)
    response.parsed_body
  end

  %w[name with_roles].each do |scope|
    context "with scope #{scope}" do
      it "is a magazine subscriber with an active subscription" do
        Fabricate(:magazine_subscription, person: user, subscription_type: "online_abo")

        expect(profile(scope)["magazine_subscriber"]).to be true
      end

      it "is no magazine subscriber without subscription" do
        expect(profile(scope)["magazine_subscriber"]).to be false
      end

      it "is no magazine subscriber with an ended subscription" do
        Fabricate(:magazine_subscription, person: user, start_date: 1.year.ago,
          end_date: 1.day.ago, cancellation_reason: "kint")

        expect(profile(scope)["magazine_subscriber"]).to be false
      end
    end
  end

  it "does not expose the flag with the email scope" do
    expect(profile("email")).not_to have_key("magazine_subscriber")
  end
end
