# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
#
#  Ported from hitobito_sac_cas. Unlike there, existing Abacus subjects are never
#  updated, as most customers are maintained in Abacus (e.g. by the shop), and
#  Abacus assigns the subject numbers instead of using the person id.

module Invoices
  module Abacus
    class SubjectInterface
      def initialize(client = nil)
        @client = client
      end

      # Makes sure the person exists as subject and customer in Abacus, so that sales
      # orders can be created for it. Returns false and sets the errors of the given
      # subject if this is not possible.
      #
      # Abacus assigns the subject numbers itself, the number is stored as
      # abacus_subject_key right after the subject has been created.
      def ensure_customer(subject)
        return create(subject) if subject.subject_id.zero?

        remote = fetch(subject.subject_id)
        if remote.nil?
          subject.errors[:abacus_subject_key] = :not_found_in_abacus
          false
        else
          complete(subject, remote)
          true
        end
      end

      def fetch(subject_id)
        return if subject_id.zero?

        client.get(:subject, subject_id, "$expand" => "Addresses,Communications,Customers")
      rescue RestClient::NotFound
        nil
      end

      private

      def create(subject)
        return false unless subject.valid?

        data = client.create(:subject, subject.subject_attrs)
        subject.assign_subject_key(data)
        create_address(subject)
        create_communications(subject)
        create_customer(subject)
        true
      end

      # Only adds what is missing, e.g. when a previous creation was interrupted.
      # Existing data of the subject is never changed.
      def complete(subject, remote)
        create_address(subject) if !address?(remote) && subject.address?
        create_communications(subject) if remote[:communications].blank?
        create_customer(subject) if remote[:customers].blank?
      end

      # Abacus creates an empty address together with every subject.
      def address?(remote)
        Array(remote[:addresses]).any? { |address| address[:city].present? }
      end

      def create_address(subject)
        client.create(:address, subject.address_attrs)
      end

      def create_communications(subject)
        subject.communication_attrs.each { |attrs| client.create(:communication, attrs) }
      end

      def create_customer(subject)
        client.create(:customer, subject.customer_attrs)
      end

      def client
        @client ||= Client.new
      end
    end
  end
end
