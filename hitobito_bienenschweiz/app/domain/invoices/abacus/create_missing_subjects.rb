# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Invoices
  module Abacus
    # Creates the Abacus subject (contact), address, communication and customer for every
    # person with an active role or an active magazine subscription that is not linked
    # to an Abacus subject yet. Existing Abacus subjects with the person's id are adopted
    # if they belong to the same person (see SubjectInterface#ensure_customer).
    class CreateMissingSubjects
      Result = Struct.new(:created, :failed, keyword_init: true)

      def initialize(client: nil, logger: nil)
        @client = client
        @logger = logger
      end

      def self.people
        Person.where(abacus_subject_key: nil)
          .where(id: Role.select(:person_id))
          .or(Person.where(abacus_subject_key: nil)
            .where(id: MagazineSubscription.active.select(:person_id)))
      end

      def run
        result = Result.new(created: [], failed: {})
        self.class.people.find_each { |person| process(person, result) }
        result
      end

      private

      def process(person, result)
        subject = Subject.new(person)
        if subject_interface.ensure_customer(subject)
          result.created << person
          log("#{person.id} #{person}: OK")
        else
          record_failure(person, result, subject.error_messages.join(", "))
        end
      rescue RestClient::Exception, SocketError, Errno::ECONNREFUSED => e
        record_failure(person, result, e.message)
      end

      def record_failure(person, result, message)
        result.failed[person] = message
        log("#{person.id} #{person}: FAILED #{message}")
      end

      def log(message)
        @logger&.call(message)
      end

      def subject_interface
        @subject_interface ||= SubjectInterface.new(@client || Client.new)
      end
    end
  end
end
