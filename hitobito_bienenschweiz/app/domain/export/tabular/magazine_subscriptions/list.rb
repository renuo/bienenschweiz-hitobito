# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Export::Tabular::MagazineSubscriptions
  # Every person with at least one Abo running on the given date, one row each.
  class List < Export::Tabular::Base
    self.row_class = PersonRow
    self.model_class = ::Person

    ADDRESS_ATTRS = %i[address_care_of street housenumber postbox zip_code town country].freeze

    def initialize(date: Time.zone.today, ability: nil)
      @date = date
      super(subscribers, ability)
    end

    def build_attribute_labels
      labels = {
        salutation: ::Person.human_attribute_name(:salutation),
        first_name: ::Person.human_attribute_name(:first_name),
        last_name: ::Person.human_attribute_name(:last_name),
        company_name: ::Person.human_attribute_name(:company_name)
      }
      ADDRESS_ATTRS.each { |attr| labels[attr] = ::Person.human_attribute_name(attr) }
      labels[:subscriptions] = I18n.t("magazine_subscription_reports.export.subscriptions")
      labels[:total_amount] = I18n.t("magazine_subscription_reports.export.total_amount")
      labels
    end

    def row_for(entry, format = nil)
      row = super
      row.date = @date
      row
    end

    private

    def subscribers
      ::Person
        .where(id: MagazineSubscription.active_on(@date).select(:person_id))
        .preload(:magazine_subscriptions)
        .order(:last_name, :first_name, :id)
    end
  end
end
