# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
#
#  Ported from hitobito_sac_cas.

module Invoices
  module Abacus
    # Credentials are read from `Settings.abacus`, which are set via ENV.
    class Config
      KEYS = %w[host mandant username password].freeze

      class << self
        def exist?
          host.present? && mandant.present?
        end

        KEYS.each do |key|
          define_method(key) do
            Settings.abacus&.public_send(key)
          end
        end
      end
    end
  end
end
