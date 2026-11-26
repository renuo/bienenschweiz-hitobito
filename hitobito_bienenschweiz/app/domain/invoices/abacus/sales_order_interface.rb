# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
#
#  Ported from hitobito_sac_cas.

module Invoices
  module Abacus
    class SalesOrderInterface
      def initialize(client = nil)
        @client = client
      end

      # creates a batch of sales orders, but without triggering the next step.
      # (this happens manually in abacus)
      def create_batch(sales_orders)
        parts = create_batch_request(sales_orders)
        batch_assign_abacus_sales_order_keys(parts)
        parts
      end

      # TODO: user_field21 is the cancellation flag of the SAC mandant,
      # verify once the Abacus mandant of BienenSchweiz is set up.
      def cancel(sales_order)
        client.update(:sales_order, sales_order.abacus_key, {user_fields: {user_field21: true}})
        sales_order.set_cancelled
      end

      private

      def create_batch_request(sales_orders)
        client.batch do
          sales_orders.each do |order|
            client.batch_context_object = order
            client.create(:sales_order, order.full_attrs)
          end
        end
      end

      def batch_assign_abacus_sales_order_keys(parts)
        parts.each do |part|
          part.context_object.assign_abacus_key(part.json) if part.created?
        end
      end

      def client
        @client ||= Client.new
      end
    end
  end
end
