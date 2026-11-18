# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz
  module MailingListPlusAddressing
    def self.enabled?
      Settings.email.mailing_list_plus_addressing && ExchangeOnlineToken.configured?
    end

    def self.mailbox
      ::MailConfig.retriever_imap.fetch(:user_name)
    end

    def self.single_address(header)
      addresses = Array(header).flat_map(&:addresses)
      addresses.first if addresses.one?
    end

    def self.direct_recipient(mail)
      single_address(mail.mail.header["To"])
    end

    def self.list_name(address)
      local_part, domain = mailbox.split("@", 2)
      pattern = /\A#{Regexp.escape(local_part)}\+([a-z][a-z0-9_.-]*)@#{Regexp.escape(domain)}\z/i
      address&.strip&.match(pattern)&.[](1)&.downcase
    end

    module ListAddress
      def mail_address
        address = super
        "#{mail_address_prefix}#{address}" if address
      end

      def mail_address_prefix
        if MailingListPlusAddressing.enabled?
          "#{MailingListPlusAddressing.mailbox.split("@",
            2).first}+"
        end
      end

      def mail_domain
        return super unless MailingListPlusAddressing.enabled?

        MailingListPlusAddressing.mailbox.split("@", 2).last
      end
    end

    module Retriever
      private

      def assign_mailing_list(mail)
        return super unless MailingListPlusAddressing.enabled?

        recipient = mail.original_to.presence || MailingListPlusAddressing.direct_recipient(mail)
        name = MailingListPlusAddressing.list_name(recipient)
        MailingList.joins(:group).where(group: {archived_at: nil}).find_by(mail_name: name) if name
      end
    end

    module InboundMail
      def sender_email
        sender = super
        return sender if sender || !MailingListPlusAddressing.enabled?

        MailingListPlusAddressing.single_address(mail.header["Sender"] || mail.header["From"])
      end
    end

    module Validator
      private

      def receiver_from_mail
        return super unless MailingListPlusAddressing.enabled?

        MailingListPlusAddressing.direct_recipient(@mail)
      end

      def sender_email
        return super unless MailingListPlusAddressing.enabled?

        @mail.sender_email&.downcase
      end
    end

    module MailFactory
      private

      def sender_via_mailinglist
        sender = super
        return sender unless MailingListPlusAddressing.enabled?

        address = Mail::Address.new(MailingListPlusAddressing.mailbox)
        address.display_name = Mail::Address.new(sender).display_name
        address.format
      end
    end
  end
end
