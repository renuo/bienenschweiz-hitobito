# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module MagazineSubscriptions
  class Report
    MONTH_COUNT = 3

    CATEGORIES = {
      buchhaendler: %w[buchhaendler_abo],
      gratis: %w[gratis_abo],
      bezahlt: MagazineSubscription::SUBSCRIPTION_TYPES - %w[buchhaendler_abo gratis_abo]
    }.freeze

    def initialize(today: Time.zone.today)
      @today = today
    end

    # Oldest first, so the table reads chronologically.
    def months
      @months ||= (1 - MONTH_COUNT..0).map { |offset| @today.beginning_of_month + offset.months }
    end

    def categories
      CATEGORIES.keys
    end

    def types
      MagazineSubscription::SUBSCRIPTION_TYPES
    end

    def amount(month, category)
      CATEGORIES.fetch(category).sum { |type| type_amount(month, type) }
    end

    def type_amount(month, type)
      sums_by_month.fetch(month)[type].to_i
    end

    def total(month)
      types.sum { |type| type_amount(month, type) }
    end

    private

    def sums_by_month
      @sums_by_month ||= months.index_with do |month|
        MagazineSubscription.active_in_month(month).group(:subscription_type).sum(:amount)
      end
    end
  end
end
