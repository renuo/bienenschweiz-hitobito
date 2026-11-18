# frozen_string_literal: true

# Copyright (c) 2026, BienenSchweiz. This file is licensed under the
# Affero General Public License version 3 or later.

Rails.application.config.x.exchange_online_imap = {
  tenant_id: ENV.fetch("BIENENSCHWEIZ_IMAP_TENANT_ID", nil),
  client_id: ENV.fetch("BIENENSCHWEIZ_IMAP_CLIENT_ID", nil),
  client_secret: ENV.fetch("BIENENSCHWEIZ_IMAP_CLIENT_SECRET", nil)
}
