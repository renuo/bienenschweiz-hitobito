# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe GeoAdminGeocoder do
  subject(:geocoder) { described_class.new }

  let(:address) { "Einisberg 178, 3415 Hasle b. Burgdorf" }

  it "returns the coordinates of a matching address" do
    stub_geo_admin(address, result: [47.01139831542969, 7.638618469238281])
    expect(geocoder.lookup(address)).to eq([47.01139831542969, 7.638618469238281])
  end

  it "falls back to places if no address matches" do
    stub_geo_admin("Volg, 6275 Ballwil")
    stub_geo_admin("Volg, 6275 Ballwil", origins: "zipcode,gg25,gazetteer", result: [47.15, 8.32])
    expect(geocoder.lookup("Volg, 6275 Ballwil")).to eq([47.15, 8.32])
  end

  it "returns nil if nothing matches" do
    stub_geo_admin("nowhere")
    stub_geo_admin("nowhere", origins: "zipcode,gg25,gazetteer")
    expect(geocoder.lookup("nowhere")).to be_nil
  end

  it "raises an error if the service fails" do
    stub_geo_admin(address, status: 500)
    expect { geocoder.lookup(address) }.to raise_error(described_class::Error, /500/)
  end

  it "raises an error on timeouts" do
    stub_request(:get, /api3.geo.admin.ch/).to_timeout
    expect { geocoder.lookup(address) }.to raise_error(described_class::Error)
  end
end
