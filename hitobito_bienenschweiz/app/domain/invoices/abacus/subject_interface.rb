# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
#
#  Ported from hitobito_sac_cas. Unlike there, existing Abacus subjects are never
#  updated, as most customers are maintained in Abacus (e.g. by the shop).

module Invoices
  module Abacus
    class SubjectInterface
      def initialize(client = nil)
        @client = client
      end

      # Makes sure the person exists as subject and customer in Abacus, so that sales
      # orders can be created for it. Returns false and sets the errors of the given
      # subject if this is not possible.
      def ensure_customer(subject)
        remote = fetch(subject.subject_or_entity_id)

        if subject.subject_id.zero?
          remote ? adopt(subject, remote) : create(subject)
        elsif remote.nil?
          subject.errors[:abacus_subject_key] = :not_found_in_abacus
          false
        else
          create_customer(subject) if remote[:customers].blank?
          true
        end
      end

      def fetch(subject_id)
        return if subject_id.zero?

        client.get(:subject, subject_id, "$expand" => "Communications,Customers")
      rescue RestClient::NotFound
        nil
      end

      private

      # The subject with the person's id already exists in Abacus.
      # Only use it if it actually is the same person.
      def adopt(subject, remote)
        unless same_person?(subject, remote)
          subject.errors[:abacus_subject_key] = :taken
          return false
        end

        subject.assign_subject_key(remote)
        create_customer(subject) if remote[:customers].blank?
        true
      end

      # Create abacus subject with id from hitobito.
      def create(subject)
        return false unless subject.valid?

        data = client.create(:subject, subject.subject_attrs.merge(id: subject.entity.id))
        subject.assign_subject_key(data)
        client.create(:address, subject.address_attrs)
        subject.communication_attrs.each { |attrs| client.create(:communication, attrs) }
        create_customer(subject)
        true
      end

      def create_customer(subject)
        client.create(:customer, subject.customer_attrs)
      end

      def same_person?(subject, remote)
        same_name?(subject, remote) && same_email?(subject, remote)
      end

      def same_name?(subject, remote)
        attrs = subject.subject_attrs.slice(:name, :first_name)
        remote.slice(*attrs.keys) == attrs
      end

      def same_email?(subject, remote)
        email_attrs = subject.primary_email_attrs
        communications = remote[:communications] || []
        return communications.blank? if email_attrs.blank?

        communications.any? do |c|
          c.fetch(:type) == email_attrs.fetch(:type) && c.fetch(:value) == email_attrs.fetch(:value)
        end
      end

      def client
        @client ||= Client.new
      end
    end
  end
end
