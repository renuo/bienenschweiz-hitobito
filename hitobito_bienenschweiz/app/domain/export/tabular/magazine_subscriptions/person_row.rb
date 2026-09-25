# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Export::Tabular::MagazineSubscriptions
  # One row per subscriber: their postal address, every active Abo with its Anzahl,
  # and the Anzahl summed over those Abos.
  class PersonRow < Export::Tabular::Row
    # Set by List#row_for so every row filters against the same date; falls back to today
    # when a row is built on its own (as in specs).
    attr_writer :date

    def country
      entry.country_label
    end

    def subscriptions
      active_subscriptions
        .map { |subscription| "#{subscription.subscription_type_label} (#{subscription.amount})" }
        .join(", ")
    end

    def total_amount
      active_subscriptions.sum(&:amount)
    end

    private

    def date
      @date ||= Time.zone.today
    end

    # Filtered in memory so the preloaded association is reused instead of querying per row.
    def active_subscriptions
      @active_subscriptions ||= entry.magazine_subscriptions
        .select { |subscription| subscription.active_on?(date) }
        .sort_by { |subscription| [subscription.subscription_type, subscription.id] }
    end
  end
end
