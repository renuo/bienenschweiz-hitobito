# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

Rails.application.config.x.exchange_online_imap = {
  tenant_id: ENV.fetch("BIENENSCHWEIZ_IMAP_TENANT_ID", nil),
  client_id: ENV.fetch("BIENENSCHWEIZ_IMAP_CLIENT_ID", nil),
  client_secret: ENV.fetch("BIENENSCHWEIZ_IMAP_CLIENT_SECRET", nil)
}
