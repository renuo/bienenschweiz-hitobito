# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Looks up WGS84 coordinates of a Swiss address with the location search of geo.admin.ch.
# Exact building addresses are preferred, otherwise the best matching place is used
# (e.g. "Volg, 6275 Ballwil" resolves to Ballwil).
class GeoAdminGeocoder
  class Error < StandardError; end

  URL = "https://api3.geo.admin.ch/rest/services/api/SearchServer"
  ORIGINS = ["address", "zipcode,gg25,gazetteer"].freeze
  TIMEOUT = 5

  # Returns [lat, lng] or nil if nothing was found. Raises Error if the service fails.
  def lookup(address)
    ORIGINS.each do |origins|
      attrs = search(address, origins)
      return [attrs["lat"], attrs["lon"]] if attrs
    end
    nil
  end

  private

  def search(address, origins)
    response = connection.get("", searchText: address, type: "locations", origins:,
      sr: 4326, limit: 1)
    raise Error, "geo.admin.ch search failed with #{response.status}" unless response.success?

    JSON.parse(response.body).fetch("results", []).first&.dig("attrs")
  rescue Faraday::Error, JSON::ParserError => e
    raise Error, e.message
  end

  def connection
    @connection ||= Faraday.new(url: URL, request: {timeout: TIMEOUT, open_timeout: TIMEOUT})
  end
end
