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
  has_many :external_invoices, as: :link, class_name: "ExternalInvoice::Magazine",
    dependent: :restrict_with_error, inverse_of: :link

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

  after_save :cancel_invoices_after_end_date, if: :saved_change_to_end_date?

  scope :list, -> { order(start_date: :desc, id: :desc) }
  scope :active, lambda { |date = Time.zone.today|
    where(start_date: ..date).where("end_date IS NULL OR end_date >= ?", date)
  }

  scope :active_in_month, lambda { |date|
    month = date.all_month
    where(start_date: ..month.end)
      .where(arel_table[:end_date].eq(nil).or(arel_table[:end_date].gteq(month.begin)))
  }

  def to_s
    [subscription_type_label, start_date && I18n.l(start_date)].compact.join(", ")
  end

  # Periods last one year from the start date. The first period is invoiced
  # by the shop, so the next period is never the first one.
  def next_period_start(date = Time.zone.today)
    years = [date.year - start_date.year, 1].max
    period_start = start_date + years.years
    (period_start < date) ? start_date + (years + 1).years : period_start
  end

  private

  def cancel_invoices_after_end_date
    return if end_date.nil?

    external_invoices.where(period_start: end_date.next_day..)
      .where(state: %w[draft open error]).find_each do |invoice|
      cancel_in_abacus = invoice.cancellable?
      invoice.update!(state: :cancelled)
      Invoices::Abacus::CancelInvoiceJob.new(invoice).enqueue! if cancel_in_abacus
    end
  end

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
