# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
#
#  Ported from hitobito_sac_cas.

module Invoices
  module Abacus
    class InvoicePosition
      attr_accessor :name, :amount, :count, :article_number

      def initialize(attributes = {})
        @count = 1
        attributes.each do |k, v|
          send(:"#{k}=", v)
        end
      end

      def total
        amount * count
      end
    end
  end
end
