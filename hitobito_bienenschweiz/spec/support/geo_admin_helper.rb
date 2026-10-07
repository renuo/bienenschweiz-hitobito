# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module GeoAdminHelper
  def stub_geo_admin(address, origins: "address", result: nil, status: 200)
    results = result ? [{attrs: {lat: result[0], lon: result[1]}}] : []
    stub_request(:get, GeoAdminGeocoder::URL)
      .with(query: hash_including(searchText: address, origins:))
      .to_return(status:, body: {results:}.to_json)
  end
end

RSpec.configure do |config|
  config.include GeoAdminHelper
end
