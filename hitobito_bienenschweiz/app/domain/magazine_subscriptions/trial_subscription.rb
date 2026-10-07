# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module MagazineSubscriptions
  # Grants a person a one year Schnupper-Abo. Without a running subscription it
  # starts on the first of next month. Otherwise one running subscription is
  # terminated at the end of its current yearly billing cycle and the
  # Schnupper-Abo is followed by an open-ended paid Abo. Ambiguous cases require
  # manual review.
  class TrialSubscription
    CANCELLATION_REASON = "jahr"
    PAID_TYPES = MagazineSubscription::SUBSCRIPTION_TYPES - %w[buchhaendler_abo gratis_abo]

    def initialize(person, today: Time.zone.today)
      @person = person
      @today = today
    end

    def create
      return if subscriptions.exists?(subscription_type: "schnupper_abo")

      existing = subscriptions.where("end_date IS NULL OR end_date >= ?", @today).to_a
      if manual_review_required?(existing)
        TrialSubscriptionMailer.manual_review(@person, existing).deliver_later
        return
      end

      MagazineSubscription.transaction do
        ensure_subscriber_role
        start_date = terminate_running_subscription(existing.first) ||
          @today.beginning_of_month.next_month
        create_subscriptions(start_date)
      end
    end

    private

    def manual_review_required?(existing)
      existing.any? && (existing.size != 1 || existing.first.amount != 1 ||
        !PAID_TYPES.include?(existing.first.subscription_type))
    end

    def ensure_subscriber_role
      role_type = Group::BienenZeitung::Abonnent.sti_name
      return if @person.roles.exists?(type: role_type)

      @person.roles.create!(type: role_type, group: Group::BienenZeitung.first!)
    end

    def create_subscriptions(start_date)
      trial = subscriptions.create!(subscription_type: "schnupper_abo",
        start_date: start_date, end_date: start_date.next_year - 1.day,
        cancellation_reason: CANCELLATION_REASON)
      subscriptions.create!(subscription_type: "abo", start_date: trial.end_date + 1.day)
    end

    def subscriptions
      @person.magazine_subscriptions
    end

    # Returns the first of the month after the subscription ends, nil if none runs.
    def terminate_running_subscription(subscription)
      return unless subscription

      subscription.update!(end_date: subscription.end_date || cycle_end(subscription),
        cancellation_reason: subscription.cancellation_reason || "ogru")
      subscription.end_date.next_month.beginning_of_month
    end

    def cycle_end(subscription)
      years = 1
      years += 1 while subscription.start_date.advance(years: years) <= @today
      subscription.start_date.advance(years: years) - 1.day
    end
  end
end
