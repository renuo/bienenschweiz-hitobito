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

  # Abbestellungsgründe gemäss Codeliste der Bienenzeitung.
  CANCELLATION_REASONS = %w[
    biwe
    dopp
    gesg
    gest
    hoal
    jahr
    kint
    ogru
    ret
    zahl
    zeit
  ].freeze

  belongs_to :person
  belongs_to :gifter, class_name: "Person", optional: true

  i18n_enum :subscription_type, SUBSCRIPTION_TYPES, queries: true
  i18n_enum :cancellation_reason, CANCELLATION_REASONS

  validates_by_schema
  validates :gifter, presence: true, if: :geschenk_abo?
  validates :gifter_id, absence: true, unless: :geschenk_abo?
  validates :amount, numericality: {only_integer: true, greater_than: 0,
                                    less_than: 2_147_483_648, allow_nil: true}
  validates :cancellation_reason, presence: true, if: -> { end_date.present? }
  validates :cancellation_reason, absence: true, unless: -> { end_date.present? }
  validate :assert_end_date_after_start_date
  validate :assert_person_is_subscriber, on: :create

  scope :list, -> { order(start_date: :desc, id: :desc) }
  scope :active, lambda { |date = Time.zone.today|
    where(start_date: ..date).where("end_date IS NULL OR end_date >= ?", date)
  }

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

  def assert_person_is_subscriber
    return if person.blank?
    return if person.roles.exists?(type: Group::BienenZeitung::Abonnent.sti_name)

    errors.add(:person, :not_subscriber)
  end
end
