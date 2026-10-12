# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe SiegelimkerProfilesHelper do
  let(:profile) { SiegelimkerProfile.new(person: Fabricate(:person)) }

  it "builds the embedded map url around the coordinates" do
    expect(helper.siegelimker_map_embed_url(BigDecimal("47.0"), BigDecimal("7.5"))).to eq(
      "https://www.openstreetmap.org/export/embed.html?" \
      "bbox=7.492,46.996,7.508,47.004&layer=mapnik&marker=47.0,7.5"
    )
  end

  it "builds the map link" do
    expect(helper.siegelimker_map_url(47.0, 7.5))
      .to eq("https://www.openstreetmap.org/?mlat=47.0&mlon=7.5#map=17/47.0/7.5")
  end

  describe "#siegelimker_coordinates_source" do
    it "describes manual coordinates" do
      profile.manual_coordinates = true
      expect(helper.siegelimker_coordinates_source(profile)).to eq("Manuell erfasst")
    end

    it "describes a missing address" do
      expect(helper.siegelimker_coordinates_source(profile)).to eq("Keine Adresse vorhanden")
    end

    it "describes geocoded coordinates" do
      profile.assign_attributes(geocoded_address: "Dorf 1", lat: 47, lng: 7)
      expect(helper.siegelimker_coordinates_source(profile))
        .to eq("Automatisch ermittelt aus «Dorf 1»")
    end

    it "describes an address which was not found" do
      profile.geocoded_address = "Dorf 1"
      expect(helper.siegelimker_coordinates_source(profile)).to start_with("«Dorf 1» konnte nicht")
    end
  end
end
