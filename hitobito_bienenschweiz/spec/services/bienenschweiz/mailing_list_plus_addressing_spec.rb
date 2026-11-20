# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

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

  it "omits the posting address from a list without a mail name" do
    list.mail_name = nil

    expect(list.mail_address).to be_nil
  end

  it "discards a tagged message with no usable sender" do
    expect do
      retriever.process_mail(incoming_mail(to: tagged_address, from: nil))
    end.not_to change(MailLog, :count)
    expect(retriever).to have_received(:delete_mail).with(42)
  end

  context "without the opt-in" do
    let(:flag) { false }

    it "keeps the address and original-recipient lookup" do
      expect(list.mail_address).to eq("mytest@#{Settings.email.list_domain}")
      retriever.process_mail(incoming_mail(to: mailbox, original_to: "mytest@example.com"))

      message = list.messages.sole
      expect(message.mail_log.status).to eq("retrieved")
      outbound = Messages::BulkMail::MailFactory.new(message).instance_variable_get(:@mail)
      expect(outbound.from).to eq([list.mail_address])
    end

    it "keeps the core recipient validation and sender extraction" do
      message = incoming_mail(to: mailbox)
      expect(MailingLists::BulkMail::ImapMailValidator.new(message)).to be_valid_mail

      message_without_envelope_sender = incoming_mail(to: mailbox, imap_sender: false)
      expect(message_without_envelope_sender.sender_email).to be_nil
    end
  end

  def incoming_mail(to:, original_to: nil, from: "Original Sender <#{sender}>", imap_sender: !flag)
    source = Mail.new(from:, to:, subject: "Plus addressing",
      body: "Test")
    source["Return-Path"] = "<#{sender}>"
    source["X-Original-To"] = original_to if original_to
    sender_address = Net::IMAP::Address.new("Original Sender", nil, "sender", "example.net")
    recipient = Net::IMAP::Address.new(nil, nil, "mailingliste", "example.com")
    envelope_sender = [sender_address] if imap_sender
    envelope = Net::IMAP::Envelope.new(nil, source.subject, nil, envelope_sender, nil, [recipient])
    Imap::Mail.build(Net::IMAP::FetchData.new(1,
      {"UID" => 42, "ENVELOPE" => envelope, "RFC822" => source.encoded}))
  end
end

describe Bienenschweiz::MailingListPlusAddressing, ".list_name" do
  let(:mailbox) { "mailingliste@example.com" }

  before { allow(MailConfig).to receive(:retriever_imap).and_return(user_name: mailbox) }

  def list_name(address) = described_class.list_name(address)

  {
    "mailingliste+mytest@example.com" => "mytest",
    "MailingListe+MyTest@EXAMPLE.COM" => "mytest",
    "  mailingliste+mytest@example.com\n" => "mytest",
    "mailingliste+my.test-list_1@example.com" => "my.test-list_1"
  }.each do |address, expected|
    it "maps #{address.inspect} to #{expected.inspect}" do
      expect(list_name(address)).to eq(expected)
    end
  end

  [
    nil,
    "",
    "mailingliste@example.com",
    "mailingliste+@example.com",
    "mailingliste+1test@example.com",
    "mailingliste+my+test@example.com",
    "mailingliste+my test@example.com",
    "mailingliste+mytest@example.net",
    "mailingliste+mytest@sub.example.com",
    "mailingliste+mytest@example.com.evil.net",
    "other+mytest@example.com",
    "xmailingliste+mytest@example.com",
    "mytest@example.com",
    "Sender <mailingliste+mytest@example.com>",
    "evil@example.net\nmailingliste+mytest@example.com"
  ].each do |address|
    it "does not map #{address.inspect}" do
      expect(list_name(address)).to be_nil
    end
  end

  context "with regexp metacharacters in the mailbox" do
    let(:mailbox) { "mailing.liste@example.com" }

    it "matches them literally" do
      expect(list_name("mailing.liste+mytest@example.com")).to eq("mytest")
      expect(list_name("mailingXliste+mytest@example.com")).to be_nil
      expect(list_name("mailing.liste+mytest@exampleXcom")).to be_nil
    end
  end
end
