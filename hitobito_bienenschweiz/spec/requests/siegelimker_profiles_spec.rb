# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe SiegelimkerProfilesController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:siegelimker) { Fabricate(:beekeeper, group_id: sektion.id) }
  let(:group) { siegelimker.roles.first.group }
  let(:admin) { people(:admin) }

  let(:profile_params) do
    {
      public_profile: "1",
      title: "Emmentaler Imkerei",
      siegelimker_since: "2018",
      honey_availability: "available",
      lat: "47.01139832",
      lng: "7.638618469",
      sales_points_attributes: {"0" => {name: "Hofladen", email: "hof@example.com"}}
    }
  end

  context "as admin" do
    before { sign_in(admin) }

    it "shows the tab on the person page" do
      get group_person_path(group, siegelimker)
      expect(response.body).to include("Website-Profil")
    end

    it "does not show the tab for people without the Siegelimker role" do
      get group_person_path(groups(:root), people(:leader))
      expect(response.body).not_to include("Website-Profil")
    end

    it "renders the show page without an existing profile" do
      get group_person_siegelimker_profile_path(group, siegelimker)
      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<li class="active"[^>]*>.*Website-Profil.*<\/li>/m)
    end

    it "renders the show page with an existing profile" do
      profile = SiegelimkerProfile.create!(person: siegelimker, title: "Emmentaler Imkerei",
        website: "https://imkerei.example.com", lat: 47.0113983, lng: 7.6386184,
        sales_points_attributes: [{name: "Hofladen", phone: "079 123 45 67"}])
      profile.background_image.attach(
        io: Rails.root.join("spec", "fixtures", "files", "logo-icon.png").open,
        filename: "bg.png"
      )

      get group_person_siegelimker_profile_path(group, siegelimker)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Emmentaler Imkerei", "https://imkerei.example.com",
        "Hofladen", "079 123 45 67", "47.0113983, 7.6386184", "Manuell erfasst")
      expect(response.body).to include("openstreetmap.org/export/embed.html?bbox=")
    end

    it "renders the edit form" do
      get edit_group_person_siegelimker_profile_path(group, siegelimker)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Titel der Imkerei")
      expect(response.body).to include("derzeit leider nicht erhältlich")
      expect(response.body).to include('data-controller="bienenschweiz--siegelimker-map"')
    end

    it "uploads a background image" do
      image = Rack::Test::UploadedFile.new(
        Rails.root.join("spec", "fixtures", "files", "logo-icon.png"), "image/png"
      )
      patch group_person_siegelimker_profile_path(group, siegelimker),
        params: {siegelimker_profile: {background_image: image}}
      expect(siegelimker.reload.siegelimker_profile.background_image).to be_attached

      get edit_group_person_siegelimker_profile_path(group, siegelimker)
      expect(response.body).to include("Hintergrundbild entfernen")
    end

    it "creates the profile on first update" do
      expect do
        patch group_person_siegelimker_profile_path(group, siegelimker),
          params: {siegelimker_profile: profile_params}
      end.to change { SiegelimkerProfile.count }.by(1)

      expect(response).to redirect_to(group_person_siegelimker_profile_path(group, siegelimker))
      profile = siegelimker.reload.siegelimker_profile
      expect(profile).to have_attributes(public_profile: true, title: "Emmentaler Imkerei",
        siegelimker_since: 2018, honey_availability: "available")
      expect(profile.lat).to eq(BigDecimal("47.01139832"))
      expect(profile.sales_points.map(&:name)).to eq(["Hofladen"])
    end

    it "updates an existing profile" do
      profile = SiegelimkerProfile.create!(person: siegelimker, title: "Alt")
      patch group_person_siegelimker_profile_path(group, siegelimker),
        params: {siegelimker_profile: {title: "Neu"}}
      expect(profile.reload.title).to eq("Neu")
    end

    it "renders the form with errors for invalid params" do
      patch group_person_siegelimker_profile_path(group, siegelimker),
        params: {siegelimker_profile: {website: "keine url"}}
      expect(response).to have_http_status(:unprocessable_content)
      expect(SiegelimkerProfile.count).to eq(0)
    end

    it "is not available for people without the Siegelimker role" do
      expect do
        get group_person_siegelimker_profile_path(groups(:root), people(:leader))
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "as the siegelimker" do
    before { sign_in(siegelimker) }

    it "shows the tab on the own person page" do
      get group_person_path(group, siegelimker)
      expect(response.body).to include("Website-Profil")
    end

    it "may edit the own profile" do
      patch group_person_siegelimker_profile_path(group, siegelimker),
        params: {siegelimker_profile: profile_params}
      expect(siegelimker.reload.siegelimker_profile.title).to eq("Emmentaler Imkerei")
    end
  end

  context "as another siegelimker" do
    let(:other) { Fabricate(:beekeeper, group_id: sektion.id) }

    before { sign_in(other) }

    it "may not see the profile" do
      expect do
        get group_person_siegelimker_profile_path(group, siegelimker)
      end.to raise_error(CanCan::AccessDenied)
    end

    it "may not edit the profile" do
      expect do
        patch group_person_siegelimker_profile_path(group, siegelimker),
          params: {siegelimker_profile: profile_params}
      end.to raise_error(CanCan::AccessDenied)
    end
  end
end
