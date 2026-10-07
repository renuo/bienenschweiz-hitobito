# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe SiegelimkerProfileGeocodeJob do
  let(:person) {
    Fabricate(:person, street: "Einisberg", housenumber: "178", zip_code: "3415", town: "Hasle")
  }
  let(:profile) { SiegelimkerProfile.create!(person:) }

  it "geocodes the profile" do
    stub_geocoding("Einisberg 178, 3415 Hasle", [47.0113983, 7.6386184])
    profile.update_columns(lat: 1, lng: 2, geocoded_address: "Old address")

    described_class.new(profile.id).perform

    expect(profile.reload).to have_attributes(lat: BigDecimal("47.0113983"),
      lng: BigDecimal("7.6386184"), geocoded_address: "Einisberg 178, 3415 Hasle")
  end

  it "ignores deleted profiles" do
    expect { described_class.new(-1).perform }.not_to raise_error
  end
end
