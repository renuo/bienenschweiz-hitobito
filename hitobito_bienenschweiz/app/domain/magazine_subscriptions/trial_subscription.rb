# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module MagazineSubscriptions
  # Grants a person a one year Schnupper-Abo. Without a running subscription it
  # starts on the first of next month. Otherwise one running subscription is
  # terminated at the end of its current yearly billing cycle and the
  # Schnupper-Abo follows directly, so the person keeps the same number of abos.
  class TrialSubscription
    CANCELLATION_REASON = "jahr"

    def initialize(person, today: Time.zone.today)
      @person = person
      @today = today
    end

    def create
      return if subscriptions.exists?(subscription_type: "schnupper_abo")

      MagazineSubscription.transaction do
        start_date = terminate_running_subscription || @today.beginning_of_month.next_month
        subscriptions.create!(
          subscription_type: "schnupper_abo",
          start_date: start_date,
          end_date: start_date.next_year - 1.day,
          cancellation_reason: CANCELLATION_REASON
        )
      end
    end

    private

    def subscriptions
      @person.magazine_subscriptions
    end

    # Returns the day after the terminated subscription ends, nil if none runs.
    def terminate_running_subscription
      subscription = subscriptions.where(end_date: nil).order(:id).min_by { |s| cycle_end(s) }
      return unless subscription

      subscription.update!(end_date: cycle_end(subscription),
        cancellation_reason: CANCELLATION_REASON)
      subscription.end_date + 1.day
    end

    def cycle_end(subscription)
      years = 1
      years += 1 while subscription.start_date.advance(years: years) <= @today
      subscription.start_date.advance(years: years) - 1.day
    end
  end
end
