# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe "people#show with website visibility of contact data", type: :request do
  let(:person) do
    Fabricate(:beekeeper, group_id: groups(:aarau_und_umgebung).id,
      email: "primary@example.com", show_email_on_website: false)
  end

  before do
    Fabricate(:additional_email, contactable: person, email: "public@example.com", public: true)
    Fabricate(:additional_email, contactable: person, email: "private@example.com", public: false)
    Fabricate(:phone_number, contactable: person, number: "+41 44 111 11 11", public: true)
    Fabricate(:phone_number, contactable: person, number: "+41 44 222 22 22", public: false)
    sign_in(people(:admin))
  end

  def included_attributes(type)
    json["included"].select { |r| r["type"] == type }.map { |r| r["attributes"] }
  end

  it "exposes whether the primary e-mail is shown on the website" do
    jsonapi_get "/api/people/#{person.id}"

    expect(response).to have_http_status(:ok)
    expect(json["data"]["attributes"]).to include(
      "email" => "primary@example.com", "show_email_on_website" => false
    )
  end

  it "exposes whether additional e-mails and phone numbers are public" do
    jsonapi_get "/api/people/#{person.id}", params: {include: "additional_emails,phone_numbers"}

    expect(response).to have_http_status(:ok)
    expect(included_attributes("additional_emails").map { |a| a.slice("email", "public") })
      .to contain_exactly({"email" => "public@example.com", "public" => true},
        {"email" => "private@example.com", "public" => false})
    expect(included_attributes("phone_numbers").map { |a| a.slice("number", "public") })
      .to contain_exactly({"number" => "+41 44 111 11 11", "public" => true},
        {"number" => "+41 44 222 22 22", "public" => false})
  end
end
