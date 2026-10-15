# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
#
#  Ported from hitobito_sac_cas.

module Invoices
  module Abacus
    class SalesOrder < Entity
      SOURCE_SYSTEM = "hitobito"
      BACKLOG_ID = 0
      TYPE = "Product"
      DISPATCH_TYPE = "Letter"

      # TODO: Placeholders taken over from the SAC magazine invoices
      # until the Abacus mandant of BienenSchweiz is set up.
      DOCUMENT_CODES = {
        magazine_subscription: "R10"
      }.with_indifferent_access.freeze

      PROCESS_FLOW_NUMBERS = {
        magazine_subscription: 4
      }.with_indifferent_access.freeze

      attr_reader :positions

      def initialize(invoice, positions = [])
        super(invoice)
        @positions = positions
      end

      def abacus_key?
        entity.abacus_sales_order_key?
      end

      def abacus_key
        return nil unless abacus_key?

        {sales_order_id: entity.abacus_sales_order_key, sales_order_backlog_id: BACKLOG_ID}
      end

      def assign_abacus_key(data)
        entity.update!(abacus_sales_order_key: data.fetch(:sales_order_id), state: :open)
      end

      def set_cancelled
        entity.update!(state: :cancelled)
      end

      def full_attrs
        sales_order_attrs.merge(
          positions: positions.map.with_index do |position, index|
            sales_order_position_attrs(position, index + 1)
          end
        )
      end

      def sales_order_attrs # rubocop:disable Metrics/AbcSize
        fake_date = 1.year.from_now.to_date
        {
          customer_id: entity.person.abacus_subject_key,
          # order_date: entity.created_at.to_date,
          # delivery_date: entity.sent_at,
          # invoice_date: entity.sent_at,
          # invoice_value_date: entity.issued_at,
          order_date: fake_date,
          delivery_date: fake_date + 20.days,
          invoice_date: fake_date,
          invoice_value_date: fake_date,
          total_amount: entity.total.to_f,
          language: entity.person.language,
          document_code_invoice: DOCUMENT_CODES.fetch(entity.invoice_kind),
          process_flow_number: PROCESS_FLOW_NUMBERS.fetch(entity.invoice_kind),
          user_fields: order_user_fields
        }
      end

      def order_user_fields
        {
          user_field1: entity.id.to_s,
          user_field2: SOURCE_SYSTEM,
          user_field3: DISPATCH_TYPE
        }
      end

      def sales_order_position_attrs(position, index)
        {
          position_number: index,
          type: TYPE,
          pricing: {price_after_finding: position.amount.to_f.round(2)},
          quantity: {
            ordered: position.count,
            charged: position.count,
            delivered: position.count
          },
          product: {
            # limit strings according to Abacus field lengths
            description: position.name.to_s[0, 100],
            product_number: position.article_number.to_s[0, 100]
          }
        }
      end
    end
  end
end
