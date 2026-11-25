# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Invoices
  module Abacus
    # Invoice data for one period of a MagazineSubscription.
    # The article of each billable subscription type is configured in
    # `Settings.magazine_subscription_invoicing.subscription_type_articles`, the article
    # numbers in `Settings.magazine_subscription_invoicing.articles`. Prices are not sent,
    # Abacus takes them from the article.
    # The invoice is addressed to the billing person (the gifter for gift subscriptions).
    class MagazineSubscriptionInvoice
      attr_reader :subscription, :period_start

      class << self
        def billable_types
          subscription_type_articles.keys.map(&:to_s)
        end

        def article(subscription_type)
          article_key = subscription_type_articles[subscription_type.to_sym]
          articles[article_key.to_sym] if article_key.present?
        end

        private

        def articles
          config.articles.to_h
        end

        def subscription_type_articles
          config.subscription_type_articles.to_h
        end

        def config
          Settings.magazine_subscription_invoicing
        end
      end

      def initialize(subscription, period_start)
        @subscription = subscription
        @period_start = period_start
      end

      # The person the invoice is addressed to.
      def person
        subscription.billing_person
      end

      def invoice?
        article.present? && article[:article_number].present?
      end

      def positions
        @positions ||= [subscription_position]
      end

      def period_end
        period_start + 1.year - 1.day
      end

      private

      def subscription_position
        InvoicePosition.new(
          name: position_name,
          article_number: article[:article_number],
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
