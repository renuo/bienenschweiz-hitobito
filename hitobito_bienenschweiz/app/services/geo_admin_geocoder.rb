# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Looks up WGS84 coordinates of a Swiss address with the location search of geo.admin.ch.
#
# The search is fuzzy and happily returns a different street with the same house number
# (e.g. "Höhenstrasse 44" for "Industriestrasse 44"), so results are only accepted if their
# street (and zip code, if given) appear in the searched address. If the house number does not
# exist, the nearest number on the same street is used. Without a matching street, the center
# of the zip code or municipality is used. Free texts like "Volg, 6275 Ballwil" or
# "Hofladen, Schattengasse 13, Mandach (24h offen)" are supported.
class GeoAdminGeocoder
  class Error < StandardError; end

  URL = "https://api3.geo.admin.ch/rest/services/api/SearchServer"
  TIMEOUT = 5
  LIMIT = 50
  LABEL_PATTERN = /\A(?<street>.+?)\s+(?<number>\d+\s?[a-z]?)\s+(?<zip>\d{4})\s+(?<town>.+)\z/i
  HOUSE_NUMBER_PATTERN = /\A\d{1,3}[a-z]?\z/
  PHONE_PATTERN = %r{(?:tel\.?:?\s*)?(?:\+41|0041|0)\s?\d{2}[\s/.-]*\d{3}[\s.-]*\d{2}[\s.-]*\d{2}}i
  MAX_WORDS = 10 # limit of the search service

  # Returns [lat, lng] or nil if nothing was found. Raises Error if the service fails.
  def lookup(address)
    text = clean(address)
    return if text.blank?

    words = normalize(text).split

    attrs = best_address(text, words) || zip_code_center(words) || municipality_center(text, words)
    [attrs["lat"], attrs["lon"]] if attrs
  end

  private

  def best_address(text, words)
    address_queries(text).each do |query|
      candidates = search(query, "address").filter_map { |attrs| address_candidate(attrs, words) }
      best = closest_house_number(candidates, house_number(words))
      return best if best
    end
    nil
  end

  # Besides the whole text, try "<street> <number> <rest>" in case a shop name precedes the
  # street, which makes the search fail ("Hoflade i de Chäsi Schattengasse 13 Mandach").
  def address_queries(text)
    tokens = text.split
    index = tokens.index { |token| normalize(token).match?(HOUSE_NUMBER_PATTERN) }
    queries = [text]
    queries << tokens[(index - 1)..].join(" ") if index && index > 1
    queries
  end

  def address_candidate(attrs, words)
    match = LABEL_PATTERN.match(strip_tags(attrs["label"].to_s))
    return unless match && contains?(words, normalize(match[:street]))

    # without zip code, the same street name in another town would match as well
    zip_codes = words.grep(/\A\d{4}\z/)
    if zip_codes.any?
      return if zip_codes.exclude?(match[:zip])
    else
      return unless contains?(words, normalize(match[:town]))
    end

    attrs.merge("number" => normalize(match[:number]).delete(" "))
  end

  def closest_house_number(candidates, number)
    return candidates.first unless number

    candidates.min_by do |attrs|
      [(attrs["number"].to_i - number.to_i).abs, (attrs["number"] == number) ? 0 : 1, attrs["number"]]
    end
  end

  def house_number(words)
    words.find { |word| word.match?(HOUSE_NUMBER_PATTERN) }
  end

  def zip_code_center(words)
    words.grep(/\A\d{4}\z/).each do |zip|
      attrs = search(zip, "zipcode").find { |result| result["detail"] == zip }
      return attrs if attrs
    end
    nil
  end

  # Searches the whole text, then single words ("Post in Gonten"), and only accepts
  # municipalities whose name appears in the text.
  def municipality_center(text, words)
    queries = [text] + words.grep(/\A[a-z]{3,}\z/)
    queries.each do |query|
      attrs = search(query, "gg25").find do |result|
        name = strip_tags(result["label"].to_s).sub(/\s*\(\w+\)\z/, "")
        contains?(words, normalize(name))
      end
      return attrs if attrs
    end
    nil
  end

  def search(text, origins)
    response = connection.get("", searchText: text, type: "locations", origins:,
      sr: 4326, limit: LIMIT)
    raise Error, "geo.admin.ch search failed with #{response.status}" unless response.success?

    JSON.parse(response.body).fetch("results", []).map { |result| result["attrs"] }
  rescue Faraday::Error, JSON::ParserError => e
    raise Error, e.message
  end

  def connection
    @connection ||= Faraday.new(url: URL, request: {timeout: TIMEOUT, open_timeout: TIMEOUT})
  end

  # Text sent to the search: without remarks in parentheses, contact details, commas and
  # abbreviations, limited to the last words (the address is usually at the end).
  def clean(address)
    address.to_s
      .gsub(/\([^)]*\)/, " ")
      .gsub(/\S+@\S+|https?:\S+|www\.\S+/i, " ")
      .gsub(PHONE_PATTERN, " ")
      .gsub(/str\.\s*/i, "strasse ")
      .gsub(/([[:alpha:]])(\d)/, '\1 \2')
      .tr(",;/", " ")
      .split.last(MAX_WORDS).join(" ")
  end

  # Lowercase words as used by geo.admin.ch (umlauts as ae/oe/ue, no accents or punctuation).
  def normalize(text)
    text = text.downcase.gsub("ä", "ae").gsub("ö", "oe").gsub("ü", "ue")
    I18n.transliterate(text).gsub(/[^a-z0-9]+/, " ").squish
  end

  def contains?(words, phrase)
    " #{words.join(" ")} ".include?(" #{phrase} ")
  end

  def strip_tags(label)
    label.gsub(/<[^>]+>/, "").squish
  end
end
