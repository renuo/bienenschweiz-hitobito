# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Abo der Bienenzeitung (bienenzeitung.ch) einer Person.
class MagazineSubscription < ApplicationRecord
  include I18nEnums

  SUBSCRIPTION_TYPES = %w[
    abo
    abo_eur
    gratis_abo
    schnupper_abo
    online_abo
    geschenk_abo
    buchhaendler_abo
  ].freeze

  belongs_to :person

  i18n_enum :subscription_type, SUBSCRIPTION_TYPES, queries: true

  validates_by_schema
  validates :amount, numericality: {only_integer: true, greater_than: 0,
                                    less_than: 2_147_483_648, allow_nil: true}
  validate :assert_end_date_after_start_date

  scope :list, -> { order(start_date: :desc, id: :desc) }

  def to_s
    [subscription_type_label, start_date && I18n.l(start_date)].compact.join(", ")
  end

  private

  def assert_end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, :not_after_start_date) if end_date < start_date
  end
end
