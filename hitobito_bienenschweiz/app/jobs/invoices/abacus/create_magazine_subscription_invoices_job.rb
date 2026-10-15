# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Creates the invoices for the next period of all billable magazine subscriptions
# in Abacus, a few months before that period starts. Invoices that failed are
# retried on the next run.
class Invoices::Abacus::CreateMagazineSubscriptionInvoicesJob < RecurringJob
  SLICE_SIZE = 25 # number of invoices transmitted per abacus batch request
  RETRYABLE_STATES = %w[draft error].freeze

  def perform_internal
    return unless config.enabled

    sales_orders = due_subscriptions.filter_map { |subscription| build_sales_order(subscription) }
    sales_orders.each_slice(SLICE_SIZE) { |batch| submit(batch) }
  end

  def next_run
    Time.zone.tomorrow.at_beginning_of_day.change(hour: 2, minute: 33).in_time_zone
  end

  private

  def due_subscriptions
    MagazineSubscription.active(today)
      .where(subscription_type: Invoices::Abacus::MagazineSubscriptionInvoice.billable_types)
      .includes(:person, :external_invoices)
      .select { |subscription| due?(subscription) }
  end

  def due?(subscription)
    period_start = subscription.next_period_start(today)
    return false if period_start > today + config.lead_time_months.months
    return false if subscription.end_date && subscription.end_date < period_start

    invoice = subscription.external_invoices.find { |i| i.period_start == period_start }
    invoice.nil? || RETRYABLE_STATES.include?(invoice.state)
  end

  def build_sales_order(subscription)
    invoice_data = Invoices::Abacus::MagazineSubscriptionInvoice.new(
      subscription, subscription.next_period_start(today)
    )
    invoice = prepare_external_invoice(invoice_data)

    if !invoice_data.invoice?
      assign_error(invoice, I18n.t("invoices.errors.article_missing",
        subscription_type: subscription.subscription_type_label))
    elsif (subject_errors = ensure_customer(subscription.person))
      assign_error(invoice, I18n.t("invoices.errors.create_subject_failed"), subject_errors)
    else
      Invoices::Abacus::SalesOrder.new(invoice, invoice_data.positions)
    end
  end

  # Creates the person as subject and customer in Abacus if missing.
  # Returns the error messages if this failed, nil otherwise.
  def ensure_customer(person)
    @subject_errors ||= {}
    return @subject_errors[person.id] if @subject_errors.key?(person.id)

    subject = Invoices::Abacus::Subject.new(person)
    @subject_errors[person.id] =
      subject_interface.ensure_customer(subject) ? nil : subject.error_messages.join(", ")
  rescue RestClient::Exception, SocketError, Errno::ECONNREFUSED => e
    @subject_errors[person.id] = e.message
  end

  def prepare_external_invoice(invoice_data)
    invoice = ExternalInvoice::Magazine.find_or_initialize_by(
      link: invoice_data.subscription,
      period_start: invoice_data.period_start
    )
    invoice.update!(
      person: invoice_data.person,
      state: :draft,
      total: invoice_data.invoice? ? invoice_data.total : 0,
      issued_at: invoice_data.period_start,
      sent_at: today
    )
    invoice
  end

  def submit(sales_orders)
    parts = sales_order_interface.create_batch(sales_orders)
    parts.reject(&:success?).each do |part|
      assign_error(part.context_object.entity, I18n.t("invoices.errors.create_invoice_failed"),
        part.error_payload)
    end
  rescue RestClient::Exception, SocketError, Errno::ECONNREFUSED => e
    sales_orders.each do |sales_order|
      assign_error(sales_order.entity, I18n.t("invoices.errors.create_invoice_failed"), e.message)
    end
  end

  def assign_error(invoice, message, payload = nil)
    invoice.update!(state: :error)
    HitobitoLogEntry.create!(
      level: :error,
      category: ExternalInvoice::ERROR_CATEGORY,
      message: message,
      payload: payload,
      subject: invoice
    )
    nil
  end

  def sales_order_interface
    @sales_order_interface ||= Invoices::Abacus::SalesOrderInterface.new(client)
  end

  def subject_interface
    @subject_interface ||= Invoices::Abacus::SubjectInterface.new(client)
  end

  def client
    @client ||= Invoices::Abacus::Client.new
  end

  def config
    Settings.magazine_subscription_invoicing
  end

  def today
    @today ||= Time.zone.today
  end
end
