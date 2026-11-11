# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module MagazineSubscriptions
  class Report
    MONTH_COUNT = 18
    SNAPSHOT_DAY = 15
    WEMF_SPECIAL_TYPES = %w[gratis_abo buchhaendler_abo].freeze

    def initialize(today: Time.zone.today)
      @today = today
    end

    def months
      @months ||= Array.new(MONTH_COUNT) { |offset| latest_month << offset }
    end

    def types
      paid_types + WEMF_SPECIAL_TYPES
    end

    def paid_types
      MagazineSubscription::SUBSCRIPTION_TYPES - WEMF_SPECIAL_TYPES
    end

    def paid_amount(month)
      paid_types.sum { |type| type_amount(month, type) }
    end

    def type_amount(month, type)
      sums_by_month.fetch(month)[type].to_i
    end

    def total(month)
      types.sum { |type| type_amount(month, type) }
    end

    private

    def latest_month
      month = @today.beginning_of_month
      (@today.day < SNAPSHOT_DAY) ? month.prev_month : month
    end

    def sums_by_month
      @sums_by_month ||= months.index_with do |month|
        MagazineSubscription.active_on(month.change(day: SNAPSHOT_DAY))
          .group(:subscription_type).sum(:amount)
      end
    end
  end
end
