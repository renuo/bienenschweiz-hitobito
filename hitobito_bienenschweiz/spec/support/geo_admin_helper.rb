# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module GeoAdminHelper
  # Stubs the geocoder used by models and jobs, see GeoAdminGeocoder spec for the HTTP level.
  def stub_geocoding(address, result = nil, error: nil)
    stub = allow(geocoder_stub).to receive(:lookup).with(address)
    error ? stub.and_raise(GeoAdminGeocoder::Error, error) : stub.and_return(result)
  end

  def geocoder_stub
    @geocoder_stub ||= instance_double(GeoAdminGeocoder).tap do |geocoder|
      allow(GeoAdminGeocoder).to receive(:new).and_return(geocoder)
    end
  end

  # Stubs a search request to geo.admin.ch, results are given as [label, lat, lon]
  # (zip codes and municipalities also need a detail).
  def stub_geo_admin_search(text, origins, *results, status: 200)
    results = results.map do |label, lat, lon, detail|
      {attrs: {label:, lat:, lon:, detail:}.compact}
    end
    stub_request(:get, GeoAdminGeocoder::URL)
      .with(query: hash_including(searchText: text, origins:))
      .to_return(status:, body: {results:}.to_json)
  end
end

RSpec.configure do |config|
  config.include GeoAdminHelper
end
