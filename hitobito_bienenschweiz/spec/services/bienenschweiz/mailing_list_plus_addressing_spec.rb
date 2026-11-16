# frozen_string_literal: true

# Copyright (c) 2026, BienenSchweiz. This file is licensed under the
# Affero General Public License version 3 or later.

require "spec_helper"

describe Bienenschweiz::MailingListPlusAddressing do
  let(:flag) { true }
  let(:mailbox) { "mailingliste@example.com" }
  let(:tagged_address) { "mailingliste+mytest@example.com" }
  let(:sender) { "sender@example.net" }
  let(:list) {
    Fabricate(:mailing_list, group: groups(:root), mail_name: "mytest", additional_sender: sender)
  }
  let(:retriever) { MailingLists::BulkMail::Retriever.new }

  before do
    allow(Settings.email).to receive(:mailing_list_plus_addressing).and_return(flag)
    allow(Bienenschweiz::ExchangeOnlineToken).to receive(:configured?).and_return(true)
    allow(MailConfig).to receive(:retriever_imap).and_return(user_name: mailbox)
    allow(retriever).to receive(:delete_mail).with(42)
    list
  end

  it "routes direct Outlook mail and uses distinct SMTP sender and bounce addresses" do
    expect do
      retriever.process_mail(incoming_mail(to: tagged_address.upcase))
    end.to change { Delayed::Job.where("handler LIKE '%Messages::DispatchJob%'").count }.by(1)

    message = list.messages.sole
    expect(message.mail_log.status).to eq("retrieved")
    expect(list.mail_address).to eq(tagged_address)

    factory = Messages::BulkMail::MailFactory.new(message)
    outbound = factory.instance_variable_get(:@mail)
    expect(outbound.from).to eq([mailbox])
    expect(outbound[:from].display_names).to eq(["Original Sender via #{tagged_address}"])
    expect(outbound.reply_to).to eq([sender])
    expect(outbound.smtp_envelope_from).to eq(tagged_address)
  end

  it "prefers a tagged original recipient over a different visible address" do
    retriever.process_mail(incoming_mail(to: mailbox, original_to: tagged_address))

    expect(list.messages.sole.mail_log.status).to eq("retrieved")
  end

  it "does not substitute the visible recipient for an untagged original recipient" do
    expect do
      retriever.process_mail(incoming_mail(to: tagged_address, original_to: mailbox))
    end.to change { MailLog.where(status: :unknown_recipient).count }.by(1)
    expect(list.messages).to be_empty
  end

  it "does not route a bare, foreign, or ambiguous recipient" do
    [mailbox, "mailingliste+mytest@example.net", "#{tagged_address}, #{mailbox}", nil].each do |to|
      expect(retriever.send(:assign_mailing_list, incoming_mail(to:))).to be_nil
    end
  end

  it "keeps the sender authorization check on tagged messages" do
    list.update!(additional_sender: "another@example.net")
    retriever.process_mail(incoming_mail(to: tagged_address))

    expect(list.messages.sole.mail_log.status).to eq("sender_rejected")
  end

  context "without the opt-in" do
    let(:flag) { false }

    it "keeps the address and original-recipient lookup" do
      expect(list.mail_address).to eq("mytest@#{Settings.email.list_domain}")
      retriever.process_mail(incoming_mail(to: mailbox, original_to: "mytest@example.com"))

      expect(list.messages.sole.mail_log.status).to eq("retrieved")
    end
  end

  def incoming_mail(to:, original_to: nil)
    source = Mail.new(from: "Original Sender <#{sender}>", to:, subject: "Plus addressing",
      body: "Test")
    source["Return-Path"] = "<#{sender}>"
    source["X-Original-To"] = original_to if original_to
    sender_address = Net::IMAP::Address.new("Original Sender", nil, "sender", "example.net")
    recipient = Net::IMAP::Address.new(nil, nil, "mailingliste", "example.com")
    envelope_sender = flag ? nil : [sender_address]
    envelope = Net::IMAP::Envelope.new(nil, source.subject, nil, envelope_sender, nil, [recipient])
    Imap::Mail.build(Net::IMAP::FetchData.new(1,
      {"UID" => 42, "ENVELOPE" => envelope, "RFC822" => source.encoded}))
  end
end
