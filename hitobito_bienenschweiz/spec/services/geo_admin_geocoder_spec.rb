# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe GeoAdminGeocoder do
  subject(:geocoder) { described_class.new }

  def lookup(address) = geocoder.lookup(address)

  context "with addresses" do
    it "returns the coordinates of the matching address" do
      stub_geo_admin_search("Einisberg 178 3415 Hasle b. Burgdorf", "address",
        ["Einisberg 178 <b>3415 Hasle b. Burgdorf</b>", 47.0113983, 7.6386184])
      expect(lookup("Einisberg 178, 3415 Hasle b. Burgdorf")).to eq([47.0113983, 7.6386184])
    end

    it "ignores other streets with the same house number" do
      stub_geo_admin_search("Industriestrasse 44 8304 Wallisellen", "address",
        ["Höhenstrasse 44 <b>8304 Wallisellen</b>", 47.4211, 8.5882],
        ["Industriestrasse 2 <b>8304 Wallisellen</b>", 47.4126, 8.5835],
        ["Industriestrasse 41d <b>8304 Wallisellen</b>", 47.4111, 8.5903],
        ["Industriestrasse 40 <b>8304 Wallisellen</b>", 47.4096, 8.5897])
      expect(lookup("Industriestrasse 44, 8304 Wallisellen")).to eq([47.4111, 8.5903])
    end

    it "prefers the exact house number" do
      stub_geo_admin_search("Kaustrasse 23 9108 Gontenbad", "address",
        ["Kaustrasse 23a <b>9108 Gontenbad</b>", 47.1, 9.1],
        ["Kaustrasse 23 <b>9108 Gontenbad</b>", 47.2, 9.2])
      expect(lookup("Kaustr.23  9108 Gontenbad")).to eq([47.2, 9.2])
    end

    it "ignores matching streets with another zip code" do
      stub_geo_admin_search("Kaustrasse 23 9108 Gontenbad", "address",
        ["Kaustrasse 23 <b>9000 St. Gallen</b>", 47.4, 9.3])
      stub_geo_admin_search("9108", "zipcode", ["<b>9108 - Gonten</b>", 47.3, 9.3, "9108"])
      expect(lookup("Kaustrasse 23, 9108 Gontenbad")).to eq([47.3, 9.3])
    end

    it "requires the town without zip code" do
      stub_geo_admin_search("Gmeisstrasse 4", "address", ["Gmeisstrasse 4 <b>8887 Mels</b>", 47.0, 9.4])
      stub_geo_admin_search("Gmeisstrasse 4", "gg25")
      stub_geo_admin_search("gmeisstrasse", "gg25")
      expect(lookup("Gmeisstrasse 4")).to be_nil

      stub_geo_admin_search("Hauensteinweg 16 Bern", "address",
        ["Hauensteinweg 16 <b>3008 Bern</b>", 46.938, 7.420])
      expect(lookup("Hauensteinweg 16, Bern")).to eq([46.938, 7.420])
    end

    it "searches the street without the preceding shop name" do
      text = "Hoflade i de Chäsi Schattengasse 13 Mandach"
      stub_geo_admin_search(text, "address")
      stub_geo_admin_search("Schattengasse 13 Mandach", "address",
        ["Schattengasse 13 <b>5318 Mandach</b>", 47.5459, 8.1857])
      expect(lookup("Hoflade i de Chäsi, Schattengasse 13, Mandach (24h offen)"))
        .to eq([47.5459, 8.1857])
    end

    it "removes contact details and limits the number of words" do
      stub_geo_admin_search("EFH - Im Ganzenbühl 15 8405 Winterthur", "address",
        ["Im Ganzenbühl 15 <b>8405 Winterthur</b>", 47.48, 8.76])
      expect(lookup("EFH - Im Ganzenbühl 15, 8405 Winterthur 079/765 55 03 info@example.com"))
        .to eq([47.48, 8.76])

      stub_geo_admin_search("eins zwei drei vier fünf sechs Gasse 1 8000 Zürich", "address",
        ["Gasse 1 <b>8000 Zürich</b>", 47.37, 8.54])
      expect(lookup("null eins zwei drei vier fünf sechs Gasse 1, 8000 Zürich")).to eq([47.37, 8.54])
    end

    it "uses the first matching street without house number" do
      stub_geo_admin_search("Einisberg 3415 Hasle", "address",
        ["Einisberg 178 <b>3415 Hasle</b>", 47.01, 7.63])
      expect(lookup("Einisberg, 3415 Hasle")).to eq([47.01, 7.63])
    end
  end

  context "with places" do
    it "falls back to the zip code" do
      stub_geo_admin_search("Volg 6275 Ballwil", "address", ["Hasli # <b>6275 Ballwil</b>", 47.15, 8.31])
      stub_geo_admin_search("6275", "zipcode", ["<b>6275 - Ballwil</b>", 47.156, 8.332, "6275"])
      expect(lookup("Volg, 6275 Ballwil")).to eq([47.156, 8.332])
    end

    it "falls back to a municipality named in the text" do
      stub_geo_admin_search("Post in Gonten", "address",
        ["Steinstrasse 1 <b>9108 Gonten</b>", 47.33, 9.36])
      stub_geo_admin_search("Post in Gonten", "gg25")
      stub_geo_admin_search("post", "gg25")
      stub_geo_admin_search("gonten", "gg25",
        ["<b>Gontenschwil (AG)</b>", 47.26, 8.14], ["<b>Gonten (AI)</b>", 47.315, 9.349])
      expect(lookup("Post in Gonten")).to eq([47.315, 9.349])
    end

    it "falls back to the municipality for unknown zip codes" do
      stub_geo_admin_search("Hofladen 9999 Gonten", "address")
      stub_geo_admin_search("9999", "zipcode", ["<b>9000 - St. Gallen</b>", 47.4, 9.3, "9000"])
      stub_geo_admin_search("Hofladen 9999 Gonten", "gg25", ["<b>Gonten (AI)</b>", 47.315, 9.349])
      expect(lookup("Hofladen, 9999 Gonten")).to eq([47.315, 9.349])
    end

    it "returns nil if nothing matches" do
      stub_request(:get, /api3.geo.admin.ch/).to_return(body: {results: []}.to_json)
      expect(lookup("irgendwo im Nirgendwo")).to be_nil
    end

    it "returns nil without searchable text" do
      expect(lookup("info@example.com")).to be_nil
    end
  end

  context "with failures" do
    it "raises an error if the service fails" do
      stub_geo_admin_search("Einisberg 178 3415 Hasle", "address", status: 500)
      expect { lookup("Einisberg 178, 3415 Hasle") }.to raise_error(described_class::Error, /500/)
    end

    it "raises an error on timeouts" do
      stub_request(:get, /api3.geo.admin.ch/).to_timeout
      expect { lookup("Einisberg 178, 3415 Hasle") }.to raise_error(described_class::Error)
    end
  end
end
