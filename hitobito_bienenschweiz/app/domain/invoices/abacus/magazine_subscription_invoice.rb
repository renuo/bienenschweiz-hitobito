# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Invoices
  module Abacus
    # Invoice data for one period of a MagazineSubscription.
    # Prices and article numbers per subscription type are configured in
    # `Settings.magazine_subscription_invoicing.articles`.
    class MagazineSubscriptionInvoice
      attr_reader :subscription, :period_start

      delegate :person, to: :subscription

      class << self
        def billable_types
          articles.keys.map(&:to_s)
        end

        def article(subscription_type)
          articles[subscription_type.to_sym]
        end

        private

        def articles
          Settings.magazine_subscription_invoicing.articles.to_h
        end
      end

      def initialize(subscription, period_start)
        @subscription = subscription
        @period_start = period_start
      end

      def invoice?
        article.present? && article[:article_number].present? && article[:price].present?
      end

      def positions
        @positions ||= [subscription_position]
      end

      def total
        positions.sum(&:total)
      end

      def period_end
        period_start + 1.year - 1.day
      end

      private

      def subscription_position
        InvoicePosition.new(
          name: position_name,
          article_number: article[:article_number],
          amount: BigDecimal(article[:price].to_s),
          count: subscription.amount
        )
      end

      def position_name
        I18n.t("invoices.magazine_subscription.position",
          subscription_type: subscription.subscription_type_label,
          period: "#{I18n.l(period_start)} - #{I18n.l(period_end)}")
      end

      def article
        self.class.article(subscription.subscription_type)
      end
    end
  end
end
