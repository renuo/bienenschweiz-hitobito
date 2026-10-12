# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe SiegelimkerProfile do
  subject(:profile) { described_class.new(person: Fabricate(:person)) }

  it { is_expected.to be_valid }

  it "defaults all products to not offered" do
    expect(profile.honey_availability).to eq("not_offered")
    expect(profile.honey_availability_label).to eq("nicht im Angebot")
  end

  it "rejects unknown availabilities" do
    profile.wax_availability = "plenty"
    expect(profile).not_to be_valid
  end

  it "validates siegelimker_since as a plausible year" do
    profile.siegelimker_since = 10
    expect(profile).not_to be_valid
    profile.siegelimker_since = Time.zone.today.year + 1
    expect(profile).not_to be_valid
    profile.siegelimker_since = 2018
    expect(profile).to be_valid
  end

  it "validates the website as http(s) url" do
    profile.website = "www.example.com"
    expect(profile).not_to be_valid
    profile.website = "https://www.example.com"
    expect(profile).to be_valid
  end

  it "validates coordinates" do
    profile.lat = 91
    expect(profile).not_to be_valid
    profile.lat = 47.01139832
    profile.lng = 7.638618469
    expect(profile).to be_valid
  end

  it "allows at most #{described_class::MAX_SALES_POINTS} sales points" do
    6.times { |i| profile.sales_points.build(name: "Laden #{i}") }
    expect(profile).not_to be_valid
    expect(profile.errors[:sales_points]).to be_present

    profile.sales_points.last.mark_for_destruction
    expect(profile).to be_valid
  end

  it "ignores blank nested sales points" do
    profile.update!(sales_points_attributes: [{name: "Hofladen"}, {name: "", address: ""}])
    expect(profile.sales_points.map(&:name)).to eq(["Hofladen"])
  end

  it "lists present bee locations" do
    profile.bee_location_1 = "Einisberg"
    profile.bee_location_3 = "Schlössli"
    expect(profile.bee_locations).to eq(%w[Einisberg Schlössli])
  end

  describe "#remove_background_image=" do
    before do
      profile.background_image.attach(
        io: Rails.root.join("spec", "fixtures", "files", "logo-icon.png").open,
        filename: "bg.png", content_type: "image/png"
      )
      profile.save!
    end

    it "always reads as false" do
      expect(profile.remove_background_image).to be(false)
    end

    it "purges the background image when set to a truthy value" do
      expect do
        profile.remove_background_image = "1"
        profile.save
      end.to change { profile.background_image.attached? }.from(true).to(false)
    end

    it "keeps the background image when set to a falsy value" do
      expect do
        profile.remove_background_image = "0"
        profile.save
      end.not_to change { profile.background_image.attached? }.from(true)
    end
  end

  describe "geocoding" do
    let(:person) do
      Fabricate(:person, street: "Einisberg", housenumber: "178", zip_code: "3415", town: "Hasle")
    end
    let(:person_address) { "Einisberg 178, 3415 Hasle" }

    subject(:profile) { described_class.new(person:) }

    it "geocodes the person address" do
      stub_geocoding(person_address, [47.0113983, 7.6386184])
      profile.save!
      expect(profile).to have_attributes(lat: BigDecimal("47.0113983"),
        lng: BigDecimal("7.6386184"), geocoded_address: person_address,
        manual_coordinates: false)
    end

    it "prefers the address of the first sales point with an address" do
      stub_geocoding("Dorfstrasse 1, 3000 Bern", [46.9, 7.4])
      profile.sales_points.build(name: "Markt")
      profile.sales_points.build(address: "Dorfstrasse 1, 3000 Bern")
      profile.sales_points.build(address: "Hauptgasse 2, 4500 Solothurn")
      profile.save!
      expect(profile.lat).to eq(BigDecimal("46.9"))
    end

    it "skips sales points marked for destruction" do
      profile.sales_points.build(address: "Dorfstrasse 1, 3000 Bern").mark_for_destruction
      expect(profile.geocoding_address).to eq(person_address)
    end

    it "does not geocode without address" do
      profile.person = Fabricate(:person)
      profile.save!
      expect(profile.lat).to be_nil
      expect(profile.geocoded_address).to be_nil
    end

    it "only looks up again when the address changes" do
      stub_geocoding(person_address, [47.0113983, 7.6386184])
      profile.save!
      profile.update!(title: "Imkerei")
      expect(geocoder_stub).to have_received(:lookup).with(person_address).once

      stub_geocoding("Dorfstrasse 1, 3000 Bern", [46.9, 7.4])
      profile.update!(sales_points_attributes: [{address: "Dorfstrasse 1, 3000 Bern"}])
      expect(profile.lat).to eq(BigDecimal("46.9"))
    end

    it "clears the coordinates if the address is not found" do
      stub_geocoding(person_address, nil)
      profile.assign_attributes(lat: nil, lng: nil, geocoded_address: "Old address")
      profile.save!
      expect(profile).to have_attributes(lat: nil, lng: nil, geocoded_address: person_address)
    end

    it "keeps the coordinates if the service fails" do
      stub_geocoding(person_address, error: "geo.admin.ch search failed with 500")
      profile.save!
      profile.update_columns(lat: 1, lng: 2, geocoded_address: "Old address")
      expect(Rails.logger).to receive(:warn).with(/failed/)
      profile.save!
      expect(profile.reload).to have_attributes(lat: 1, lng: 2, geocoded_address: "Old address")
    end

    it "keeps manually entered coordinates" do
      profile.update!(lat: 46.5, lng: 7.5)
      expect(profile).to have_attributes(manual_coordinates: true, geocoded_address: nil)

      profile.update!(sales_points_attributes: [{address: "Dorfstrasse 1, 3000 Bern"}])
      expect(profile.lat).to eq(BigDecimal("46.5"))
    end

    it "geocodes again when the manual coordinates are cleared" do
      profile.update!(lat: 46.5, lng: 7.5)
      stub_geocoding(person_address, [47.0113983, 7.6386184])
      profile.update!(lat: nil, lng: nil)
      expect(profile).to have_attributes(manual_coordinates: false, lat: BigDecimal("47.0113983"))
    end

    it "requires both coordinates" do
      profile.lat = 46.5
      expect(profile).not_to be_valid
      expect(profile.errors[:lng]).to be_present

      profile.assign_attributes(lat: nil, lng: 7.5)
      expect(profile).not_to be_valid
      expect(profile.errors[:lat]).to be_present
    end

    it "keeps assigned geocoded coordinates until the address changes" do
      profile.assign_geocoded_coordinates(47.0113983, 7.6386184)
      profile.save!
      expect(profile).to have_attributes(manual_coordinates: false,
        geocoded_address: person_address, lat: BigDecimal("47.0113983"))
    end
  end

  describe "#to_s" do
    it "uses the title and falls back to the person" do
      expect(profile.to_s).to eq(profile.person.to_s)
      profile.title = "Emmentaler Imkerei"
      expect(profile.to_s).to eq("Emmentaler Imkerei")
    end
  end
end

describe SiegelimkerSalesPoint do
  it "joins name and address" do
    expect(described_class.new(name: "Hofladen", address: "Dorf 1").to_s).to eq("Hofladen, Dorf 1")
    expect(described_class.new(address: "Dorf 1").to_s).to eq("Dorf 1")
  end
end
