# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::SubjectInterface do
  let(:host) { "https://abacus.example.com" }
  let(:api) { "#{host}/api/entity/v1/mandants/1234" }
  let(:person) do
    Fabricate(:person, first_name: "Maja", last_name: "Biene", email: "maja@example.com",
      gender: "w", street: "Bienenweg", housenumber: "3", zip_code: "3000", town: "Bern",
      country: "CH", language: "de")
  end
  let(:subject) { Invoices::Abacus::Subject.new(person) }
  let(:interface) { described_class.new }

  let(:remote_subject) do
    {Id: 100_000, Name: "Biene", FirstName: "Maja",
     Addresses: [{Id: 1, City: "Bern"}],
     Communications: [{Id: 1, Type: "EMail", Value: "maja@example.com"}],
     Customers: [{Id: 100_000}]}
  end

  before do
    allow(Invoices::Abacus::Config).to receive_messages(host:, mandant: 1234,
      username: "user", password: "secret")
    stub_request(:get, "#{host}/.well-known/openid-configuration")
      .to_return(status: 200, body: {token_endpoint: "#{host}/oauth/token"}.to_json)
    stub_request(:post, "#{host}/oauth/token")
      .to_return(status: 200, body: {access_token: "token", expires_in: 600}.to_json)
  end

  def stub_get_subject(id, response)
    stub_request(:get, "#{api}/Subjects(Id=#{id})")
      .with(query: {"$expand" => "Addresses,Communications,Customers"})
      .to_return(**response)
  end

  def stub_create(path, body, response = {})
    stub_request(:post, "#{api}/#{path}")
      .with(body: body.to_json)
      .to_return(status: 201, body: response.to_json)
  end

  let(:address_body) do
    {SubjectId: 100_000, Street: "Bienenweg", HouseNumber: "3",
     PostOfficeBoxText: "", AddressSupplement: "", PostCode: "3000", City: "Bern",
     CountryId: "CH", ValidFrom: Time.zone.today}
  end
  let(:communication_body) do
    {SubjectId: 100_000, Type: "EMail", Value: "maja@example.com", Category: "Private"}
  end
  let(:customer_body) { {SubjectId: 100_000, CustomerReminder: {DispatchType: "Letter"}} }

  context "without abacus subject key" do
    it "creates subject with the number assigned by abacus, address, communication and customer" do
      requests = [
        stub_create("Subjects",
          {Type: "Person", Name: "Biene", FirstName: "Maja", SalutationId: 2, Language: "de"},
          {Id: 100_000}),
        stub_create("Addresses", address_body),
        stub_create("Communications", communication_body),
        stub_create("Customers", customer_body)
      ]

      expect(interface.ensure_customer(subject)).to be(true)

      expect(requests).to all(have_been_requested)
      expect(person.reload.abacus_subject_key).to eq(100_000)
    end

    it "keeps the subject key if creating the details fails" do
      stub_create("Subjects", {Type: "Person", Name: "Biene", FirstName: "Maja",
                               SalutationId: 2, Language: "de"}, {Id: 100_000})
      stub_request(:post, "#{api}/Addresses").to_return(status: 500, body: "{}")

      expect { interface.ensure_customer(subject) }.to raise_error(RestClient::Exception)
      expect(person.reload.abacus_subject_key).to eq(100_000)
    end

    it "returns false without address" do
      person.update!(town: nil)

      expect(interface.ensure_customer(subject)).to be(false)
      expect(subject.errors).to eq(town: :blank)
      expect(a_request(:any, /#{api}/)).not_to have_been_made
    end
  end

  context "with abacus subject key" do
    before { person.update!(abacus_subject_key: 100_000) }

    it "does nothing if subject is complete" do
      stub_get_subject(100_000, status: 200, body: remote_subject.to_json)

      expect(interface.ensure_customer(subject)).to be(true)
      expect(a_request(:post, /#{api}/)).not_to have_been_made
      expect(person.reload.abacus_subject_key).to eq(100_000)
    end

    it "creates the customer if missing" do
      stub_get_subject(100_000, status: 200, body: remote_subject.merge(Customers: []).to_json)
      request = stub_create("Customers", customer_body)

      expect(interface.ensure_customer(subject)).to be(true)
      expect(request).to have_been_requested
    end

    it "creates address, communication and customer of an incomplete subject" do
      stub_get_subject(100_000, status: 200,
        body: remote_subject.merge(Addresses: [{Id: 1, City: ""}], Communications: [],
          Customers: []).to_json)
      requests = [
        stub_create("Addresses", address_body),
        stub_create("Communications", communication_body),
        stub_create("Customers", customer_body)
      ]

      expect(interface.ensure_customer(subject)).to be(true)
      expect(requests).to all(have_been_requested)
    end

    it "does not create an address if the person has none" do
      person.update!(town: nil)
      stub_get_subject(100_000, status: 200, body: remote_subject.merge(Addresses: []).to_json)

      expect(interface.ensure_customer(subject)).to be(true)
      expect(a_request(:post, /#{api}/)).not_to have_been_made
    end

    it "returns false if the subject does not exist in abacus" do
      stub_get_subject(100_000, status: 404, body: "{}")

      expect(interface.ensure_customer(subject)).to be(false)
      expect(subject.errors).to eq(abacus_subject_key: :not_found_in_abacus)
      expect(subject.error_messages).to eq(["Abacus Kundennummer wurde in Abacus nicht gefunden"])
    end
  end
end
