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

  # Every Abo running at any point during the range: started on or before it ends and
  # either still open or ended on or after it begins.
  scope :active_between, lambda { |range|
    where(start_date: ..range.end)
      .where(arel_table[:end_date].eq(nil).or(arel_table[:end_date].gteq(range.begin)))
  }

  scope :active_in_month, ->(date) { active_between(date.all_month) }

  scope :active_on, ->(date) { active_between(date..date) }

  def to_s
    [subscription_type_label, start_date && I18n.l(start_date)].compact.join(", ")
  end

  # In-memory counterpart of the active_on scope, for preloaded subscriptions.
  def active_on?(date)
    start_date <= date && (end_date.nil? || end_date >= date)
  end

  private

  def assert_end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, :not_after_start_date) if end_date < start_date
  end
end
