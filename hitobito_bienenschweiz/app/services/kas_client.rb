# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class KasClient
  class Error < StandardError; end

  def initialize
    @base_url = Settings.kas.base_url
    @api_token = Settings.kas.api_token
  end

  def create_fee(fee_params)
    response = connection.post("/api/v1/fees") do |req|
      req.body = {fee: fee_params}.to_json
    end

    handle_response(response)
  end

  private

  def connection
    @connection ||= Faraday.new(url: @base_url) do |f|
      f.headers["Content-Type"] = "application/json"
      f.headers["Accept"] = "application/json"
      f.headers["Api-Key"] = @api_token.to_s
    end
  end

  def handle_response(response)
    return JSON.parse(response.body) if response.success?
    raise Error, JSON.parse(response.body)["error"] if response.status == 422

    raise Error, "KAS API error #{response.status}: #{response.body}"
  end
end
