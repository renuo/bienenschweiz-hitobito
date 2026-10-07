# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe PersonResource, type: :resource do
  include Rails.application.routes.url_helpers
  let(:person) { people(:admin) }

  let(:record) do
    Fabricate(:person, export_to_website: false).tap do |p|
      Fabricate(:role, person: p, group: groups(:root),
        type: Group::Dachverband::AdministratorBienenSchweiz.sti_name)
    end
  end

  it "includes export_to_website" do
    params[:filter] = {id: {eq: record.id}}
    render
    expect(jsonapi_data[0].attributes["export_to_website"]).to eq false
  end

  describe "siegelimker_profile" do
    let(:siegelimker) { Fabricate(:beekeeper, group_id: groups(:aarau_und_umgebung).id) }
    let!(:profile) do
      SiegelimkerProfile.create!(person: siegelimker, public_profile: true,
        title: "Emmentaler Imkerei", siegelimker_since: 2018, honey_availability: "available",
        bee_location_1: "Einisberg", lat: 47.01139832, lng: 7.638618469,
        sales_points_attributes: [{name: "Hofladen", email: "hof@example.com"}])
    end

    def sideloaded(type)
      jsonapi_included.select { |r| r.jsonapi_type == type }
    end

    before do
      params[:filter] = {id: {eq: siegelimker.id}}
      params[:include] = "siegelimker_profile.sales_points"
    end

    it "sideloads the profile with its sales points" do
      render

      profile_data = sideloaded("siegelimker_profiles").first
      expect(profile_data.attributes).to include(
        "person_id" => siegelimker.id, "public_profile" => true,
        "title" => "Emmentaler Imkerei", "siegelimker_since" => 2018,
        "honey_availability" => "available", "wax_availability" => "not_offered",
        "bee_location_1" => "Einisberg", "lat" => 47.01139832, "lng" => 7.638618469,
        "background_image" => nil
      )
      expect(sideloaded("siegelimker_sales_points").map { |r| r.attributes["name"] })
        .to eq(["Hofladen"])
    end

    it "includes the background image url" do
      profile.background_image.attach(
        io: Rails.root.join("spec", "fixtures", "files", "logo-icon.png").open,
        filename: "bg.png", content_type: "image/png"
      )
      render

      expect(sideloaded("siegelimker_profiles").first.attributes["background_image"])
        .to start_with("http://example.com/rails/active_storage/blobs/").and end_with("bg.png")
    end

    context "for a user who may not read the person" do
      # Siegelimker of an unrelated Sektion
      let(:person) { Fabricate(:beekeeper) }

      it "does not include the profile" do
        # bypass the person visibility to check the profile is still hidden
        allow_any_instance_of(PersonResource).to receive(:base_scope).and_return(Person.all)
        render

        expect(jsonapi_data[0].id).to eq(siegelimker.id)
        expect(json).not_to have_key("included")
      end
    end
  end
end
