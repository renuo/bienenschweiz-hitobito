# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe "people#show with siegelimker profile", type: :request do
  let(:siegelimker) { Fabricate(:beekeeper, group_id: groups(:aarau_und_umgebung).id) }
  let!(:profile) do
    SiegelimkerProfile.create!(person: siegelimker, title: "Emmentaler Imkerei", lat: 47, lng: 7,
      sales_points_attributes: [{name: "Hofladen"}])
  end

  before { sign_in(people(:admin)) }

  it "includes the profile and its sales points with all attributes" do
    jsonapi_get "/api/people/#{siegelimker.id}",
      params: {include: "siegelimker_profile.sales_points"}

    expect(response).to have_http_status(:ok)
    included = json["included"].index_by { |r| r["type"] }
    expect(included["siegelimker_profiles"]["attributes"]).to include(
      "title" => "Emmentaler Imkerei"
    )
    expect(included["siegelimker_sales_points"]["attributes"]).to include("name" => "Hofladen")
  end

  it "includes the profile with all attributes when listing people" do
    jsonapi_get "/api/people",
      params: {include: "siegelimker_profile.sales_points", filter: {id: {eq: siegelimker.id}}}

    expect(response).to have_http_status(:ok)
    included = json["included"].index_by { |r| r["type"] }
    expect(included["siegelimker_profiles"]["attributes"]).to include(
      "title" => "Emmentaler Imkerei"
    )
    expect(included["siegelimker_sales_points"]["attributes"]).to include("name" => "Hofladen")
  end

  it "preloads the background images when listing people" do
    image = Rails.root.join("spec", "fixtures", "files", "images", "logo.png")
    others = Fabricate.times(2, :beekeeper, group_id: groups(:aarau_und_umgebung).id)
    [siegelimker, *others].each do |person|
      profile = person.siegelimker_profile || SiegelimkerProfile.create!(person:, title: "Profil")
      profile.background_image.attach(io: File.open(image), filename: "logo.png")
    end

    counter = QueryHelpers.count_queries do
      jsonapi_get "/api/people",
        params: {include: "siegelimker_profile",
                 filter: {id: {eq: [siegelimker, *others].map(&:id).join(",")}}}
    end

    expect(response).to have_http_status(:ok)
    lazy_loads = counter.queries.select { |q|
      q[:location].include?("siegelimker_profile_resource")
    }
    expect(lazy_loads).to be_empty
    images = json["included"].map { |r| r["attributes"]["background_image"] }
    expect(images).to all(include("logo.png"))
  end

  context "with a service token" do
    let(:service_token) do
      Fabricate(:service_token, layer: groups(:root), people: true,
        permission: :layer_and_below_read)
    end

    def jsonapi_headers
      super.merge("X-TOKEN" => service_token.token)
    end

    before { sign_out(people(:admin)) }

    it "includes the profile with all attributes" do
      jsonapi_get "/api/people",
        params: {include: "siegelimker_profile.sales_points", filter: {id: {eq: siegelimker.id}}}

      expect(response).to have_http_status(:ok)
      included = json["included"].index_by { |r| r["type"] }
      expect(included["siegelimker_profiles"]["attributes"])
        .to include("title" => "Emmentaler Imkerei")
    end
  end
end
