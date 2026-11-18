# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz
  module ImapConnector
    private

    def connect
      return super unless ExchangeOnlineToken.configured?
      return if @connected

      token = ExchangeOnlineToken.access_token
      @imap = Net::IMAP.new(config(:address), port: config(:imap_port), ssl: true)
      @imap.authenticate("XOAUTH2", config(:user_name), token)
      @connected = true
    end

    def disconnect
      return super unless ExchangeOnlineToken.configured?

      imap, @imap = @imap, nil
      @connected = false
      imap.disconnect if imap && !imap.disconnected?
    end
  end
end
