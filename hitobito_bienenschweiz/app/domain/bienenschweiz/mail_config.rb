# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz
  module MailConfig
    private

    def config_file
      return super unless ExchangeOnlineToken.configured?

      @exchange_online_config ||= {imap: exchange_online_imap_config}
    end

    def exchange_online_imap_config
      retriever = Settings.email.retriever
      config = retriever.config
      unless retriever.type == "imap" && config&.address.present? && config.user_name.present?
        raise ExchangeOnlineToken::Error,
          "Exchange Online requires RAILS_MAIL_RETRIEVER_TYPE=imap and address and user_name " \
          "in RAILS_MAIL_RETRIEVER_CONFIG"
      end

      {
        address: config.address,
        user_name: config.user_name,
        imap_port: config.port || 993,
        interval: retriever.interval
      }
    end
  end
end
