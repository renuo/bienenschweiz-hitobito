# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Creates the invoices for the next period of all billable magazine subscriptions
# in Abacus, a few months before that period starts.
#
# Failed invoices (state error) are not retried, as the error might have happened after
# the invoice was already created in Abacus. They have to be resolved manually, e.g. by
# setting them back to draft, which makes the next run create them again.
#
# Every run with due subscriptions is recorded as ExternalInvoiceRun, with an error
# log entry per failed invoice. Unexpected exceptions only fail the affected
# subscription or batch, the run continues with the others.
class Invoices::Abacus::CreateMagazineSubscriptionInvoicesJob < RecurringJob
  SLICE_SIZE = 25 # number of invoices transmitted per abacus batch request
  RETRYABLE_STATES = %w[draft].freeze

  # limit: only invoice the first n due subscriptions (e.g. to test the invoicing manually)
  def perform_internal(limit: nil)
    return unless config.enabled

    subscriptions = due_subscriptions
    subscriptions = subscriptions.first(limit) if limit
    return if subscriptions.empty?

    run_invoicing(subscriptions)
  end

  def next_run
    Time.zone.tomorrow.at_beginning_of_day.change(hour: 2, min: 33).in_time_zone
  end

  private

  def run_invoicing(subscriptions)
    @created_count = 0
    @run = ExternalInvoiceRun.create!(started_at: Time.current, due_count: subscriptions.size)
    sales_orders = subscriptions.filter_map { |subscription| build_sales_order(subscription) }
    sales_orders.each_slice(SLICE_SIZE) { |batch| submit(batch) }
    @run.finish!(:finished, created_count: @created_count)
  rescue => e
    fail_run(e) if @run&.persisted?
    raise
  end

  def fail_run(error)
    log_error(@run, I18n.t("invoices.errors.run_failed"), exception_payload(error))
    @run.finish!(:failed, created_count: @created_count)
  end

  def due_subscriptions
    MagazineSubscription.active(today)
      .where(subscription_type: Invoices::Abacus::MagazineSubscriptionInvoice.billable_types)
      .includes(:person, :gifter, :external_invoices)
      .select { |subscription| due?(subscription) }
  end

  def due?(subscription)
    period_start = subscription.next_period_start(today)
    return false if period_start > today + config.lead_time_months.months
    return false if subscription.end_date && subscription.end_date < period_start

    invoice = subscription.external_invoices.find { |i| i.period_start == period_start }
    invoice.nil? || RETRYABLE_STATES.include?(invoice.state)
  end

  def build_sales_order(subscription) # rubocop:disable Metrics/MethodLength
    invoice = nil
    invoice_data = Invoices::Abacus::MagazineSubscriptionInvoice.new(
      subscription, subscription.next_period_start(today)
    )
    invoice = prepare_external_invoice(invoice_data)

    if !invoice_data.invoice?
      assign_error(invoice, I18n.t("invoices.errors.article_missing",
        subscription_type: subscription.subscription_type_label))
    elsif (subject_errors = ensure_customer(invoice_data.person))
      assign_error(invoice, I18n.t("invoices.errors.create_subject_failed"), subject_errors)
    else
      Invoices::Abacus::SalesOrder.new(invoice, invoice_data.positions)
    end
  rescue => e
    assign_error(invoice || subscription, I18n.t("invoices.errors.unexpected"),
      exception_payload(e))
  end

  # Creates the person as subject and customer in Abacus if missing.
  # Returns the error messages if this failed, nil otherwise.
  def ensure_customer(person)
    @subject_errors ||= {}
    return @subject_errors[person.id] if @subject_errors.key?(person.id)

    subject = Invoices::Abacus::Subject.new(person)
    @subject_errors[person.id] =
      subject_interface.ensure_customer(subject) ? nil : subject.error_messages.join(", ")
  rescue => e
    @subject_errors[person.id] = exception_payload(e)
  end

  def prepare_external_invoice(invoice_data)
    invoice = ExternalInvoice::Magazine.find_or_initialize_by(
      link: invoice_data.subscription,
      period_start: invoice_data.period_start
    )
    invoice.update!(
      person: invoice_data.person,
      state: :draft,
      total: 0, # set to the total calculated by Abacus once the invoice is created there
      issued_at: invoice_data.period_start,
      sent_at: today
    )
    invoice
  end

  def submit(sales_orders)
    parts = sales_order_interface.create_batch(sales_orders)
    failed, succeeded = parts.partition { |part| !part.success? }
    @created_count += succeeded.size
    failed.each do |part|
      assign_error(part.context_object.entity, I18n.t("invoices.errors.create_invoice_failed"),
        part.error_payload)
    end
  rescue => e
    sales_orders.each do |sales_order|
      assign_error(sales_order.entity, I18n.t("invoices.errors.create_invoice_failed"),
        exception_payload(e))
    end
  end

  # Marks the invoice as error (if there is one) and logs the error on it.
  def assign_error(subject, message, payload = nil)
    subject.update!(state: :error) if subject.is_a?(ExternalInvoice)
    log_error(subject, message, payload)
    nil
  end

  def log_error(subject, message, payload)
    HitobitoLogEntry.create!(
      level: :error,
      category: ExternalInvoice::ERROR_CATEGORY,
      message: message,
      payload: payload,
      subject: subject,
      external_invoice_run: @run
    )
  end

  def exception_payload(error)
    response = error.response if error.respond_to?(:response)
    {
      error: "#{error.class}: #{error.message}",
      response: response.try(:body).presence,
      backtrace: Array(error.backtrace).first(5)
    }.compact
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
