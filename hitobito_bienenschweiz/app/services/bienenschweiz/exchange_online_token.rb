# frozen_string_literal: true

# Copyright (c) 2026, BienenSchweiz. This file is licensed under the
# Affero General Public License version 3 or later.

module Bienenschweiz
  class ExchangeOnlineToken
    class Error < StandardError; end

    SCOPE = "https://outlook.office365.com/.default"
    RENEWAL_MARGIN = 60
    LOCK = Mutex.new

    class << self
      def configured?
        configuration.values.any?
      end

      def access_token
        LOCK.synchronize do
          return @access_token if @renew_at && monotonic_time < @renew_at

          renew_token
        end
      end

      private

      def renew_token
        requested_at = monotonic_time
        payload = JSON.parse(request_token)
        raise Error, "Invalid Exchange Online token response" unless payload.is_a?(Hash)

        token = payload["access_token"]
        lifetime = Integer(payload["expires_in"], exception: false).to_i
        unless token.is_a?(String) && token.present? && lifetime.positive?
          raise Error, "Invalid Exchange Online token response"
        end

        @renew_at = requested_at + lifetime - RENEWAL_MARGIN
        @access_token = token
      rescue JSON::ParserError
        raise Error, "Invalid Exchange Online token response", cause: nil
      end

      def request_token
        connection = Faraday.new(url: "https://login.microsoftonline.com") do |faraday|
          faraday.request :url_encoded
          faraday.options.open_timeout = 5
          faraday.options.timeout = 10
        end
        response = connection.post(token_path, {
          grant_type: "client_credentials",
          scope: SCOPE,
          client_id: required_config(:client_id),
          client_secret: required_config(:client_secret)
        })
        return response.body if response.success?

        raise Error, "Exchange Online token request failed (HTTP #{response.status})"
      rescue Faraday::Error
        raise Error, "Could not reach the Exchange Online token endpoint", cause: nil
      end

      def token_path
        tenant_id = required_config(:tenant_id)
        unless tenant_id.match?(/\A[0-9a-z][0-9a-z.-]*\z/i)
          raise Error, "Invalid Exchange Online IMAP tenant_id"
        end

        "/#{tenant_id}/oauth2/v2.0/token"
      end

      def required_config(name)
        configuration[name].presence || raise(Error, "Missing #{name} for Exchange Online IMAP")
      end

      def configuration
        Rails.configuration.x.exchange_online_imap
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
