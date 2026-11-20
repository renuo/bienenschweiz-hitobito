# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Invoices
  module Abacus
    # Transfers the links between hitobito and Abacus (person -> subject key,
    # external invoice -> sales order key) from one hitobito instance to another
    # that shares the same Abacus mandant, e.g. after a test export from a local
    # database to the Abacus test instance.
    #
    # Records are matched by id. As ids may differ between instances, every record
    # is verified (person name, subscription owner) and skipped if it does not match.
    class KeyMapping
      VERSION = 1
      PERSON_ATTRS = %w[first_name last_name company_name].freeze
      INVOICE_ATTRS = %w[
        type state period_start issued_at sent_at total abacus_sales_order_key
      ].freeze

      Result = Struct.new(:people, :invoices, :skipped, keyword_init: true) do
        def initialize(people: 0, invoices: 0, skipped: [])
          super
        end
      end

      def self.export
        {
          version: VERSION,
          exported_at: Time.current.iso8601,
          people: export_people,
          external_invoices: export_invoices
        }
      end

      def self.export_people
        Person.where.not(abacus_subject_key: nil).order(:id).map do |person|
          {id: person.id, abacus_subject_key: person.abacus_subject_key}
            .merge(person.attributes.slice(*PERSON_ATTRS))
        end
      end

      def self.export_invoices
        ExternalInvoice.where.not(abacus_sales_order_key: nil).order(:id).map do |invoice|
          {person_id: invoice.person_id, link_type: invoice.link_type, link_id: invoice.link_id}
            .merge(invoice.attributes.slice(*INVOICE_ATTRS))
        end
      end

      def initialize(data, dry_run: false, logger: nil)
        @data = data.deep_stringify_keys
        @dry_run = dry_run
        @logger = logger
        @result = Result.new
      end

      def import
        unless @data["version"] == VERSION
          raise ArgumentError, "Unsupported mapping version #{@data["version"].inspect}"
        end

        ActiveRecord::Base.transaction do
          Array(@data["people"]).each { |row| import_person(row) }
          Array(@data["external_invoices"]).each { |row| import_invoice(row) }
          raise ActiveRecord::Rollback if @dry_run
        end
        @result
      end

      private

      def import_person(row)
        person = Person.find_by(id: row["id"])
        return skip("Person #{row["id"]}: not found") unless person
        unless same_person?(person, row)
          return skip("Person #{person.id}: name mismatch (#{person})")
        end

        assign_subject_key(person, row["abacus_subject_key"])
      end

      def assign_subject_key(person, key)
        return if person.abacus_subject_key == key

        if (other = Person.where.not(id: person.id).find_by(abacus_subject_key: key))
          return skip("Person #{person.id}: key #{key} already used by person #{other.id}")
        end
        if person.abacus_subject_key.present?
          log("Person #{person.id}: replacing key #{person.abacus_subject_key} with #{key}")
        end

        person.update_column(:abacus_subject_key, key) # rubocop:disable Rails/SkipsModelValidations
        @result.people += 1
      end

      def import_invoice(row)
        label = "Invoice #{row["link_type"]} #{row["link_id"]} #{row["period_start"]}"
        link = row["link_type"].safe_constantize&.find_by(id: row["link_id"])
        return skip("#{label}: link not found") unless link
        return skip("#{label}: belongs to other person") unless link.person_id == row["person_id"]

        invoice = ExternalInvoice.find_or_initialize_by(
          link: link, period_start: row["period_start"]
        )
        invoice.assign_attributes(row.slice(*INVOICE_ATTRS).merge("person_id" => link.person_id))
        # Callbacks run on purpose: a cancelled invoice terminates the subscription,
        # as it did on the source instance.
        invoice.save!
        @result.invoices += 1
      end

      def same_person?(person, row)
        PERSON_ATTRS.all? { |attr| person.send(attr).to_s.strip == row[attr].to_s.strip }
      end

      def skip(message)
        @result.skipped << message
        log("SKIPPED #{message}")
        nil
      end

      def log(message)
        @logger&.call(message)
      end
    end
  end
end
