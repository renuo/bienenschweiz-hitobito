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
    {Id: person.id, Name: "Biene", FirstName: "Maja",
     Communications: [{Id: 1, Type: "EMail", Value: "maja@example.com"}],
     Customers: [{Id: person.id}]}
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
      .with(query: {"$expand" => "Communications,Customers"})
      .to_return(**response)
  end

  def stub_create(path, body, response = {})
    stub_request(:post, "#{api}/#{path}")
      .with(body: body.to_json)
      .to_return(status: 201, body: response.to_json)
  end

  context "without abacus subject key" do
    context "when subject does not exist in abacus" do
      before { stub_get_subject(person.id, status: 404, body: "{}") }

      it "creates subject, address, communication and customer" do
        requests = [
          stub_create("Subjects",
            {Type: "Person", Name: "Biene", FirstName: "Maja", SalutationId: 2,
             Language: "de", Id: person.id},
            {Id: person.id}),
          stub_create("Addresses",
            {SubjectId: person.id, Street: "Bienenweg", HouseNumber: "3",
             PostOfficeBoxText: "", AddressSupplement: "", PostCode: "3000", City: "Bern",
             CountryId: "CH", ValidFrom: Time.zone.today}),
          stub_create("Communications",
            {SubjectId: person.id, Type: "EMail", Value: "maja@example.com",
             Category: "Private"}),
          stub_create("Customers",
            {SubjectId: person.id, CustomerReminder: {DispatchType: "Letter"}})
        ]

        expect(interface.ensure_customer(subject)).to be(true)

        expect(requests).to all(have_been_requested)
        expect(person.reload.abacus_subject_key).to eq(person.id)
      end

      it "returns false without address" do
        person.update!(town: nil)

        expect(interface.ensure_customer(subject)).to be(false)
        expect(subject.errors).to eq(town: :blank)
        expect(a_request(:post, /#{api}/)).not_to have_been_made
      end

      it "fails if abacus assigns a different subject key" do
        stub_request(:post, "#{api}/Subjects")
          .to_return(status: 201, body: {Id: 4711}.to_json)

        expect { interface.ensure_customer(subject) }
          .to raise_error("Abacus created subject with id=4711 but person has id=#{person.id}")
      end
    end

    context "when subject with person id exists in abacus" do
      it "assigns the key if it is the same person" do
        stub_get_subject(person.id, status: 200, body: remote_subject.to_json)

        expect(interface.ensure_customer(subject)).to be(true)
        expect(person.reload.abacus_subject_key).to eq(person.id)
      end

      it "creates the customer if missing" do
        stub_get_subject(person.id, status: 200,
          body: remote_subject.merge(Customers: []).to_json)
        request = stub_create("Customers",
          {SubjectId: person.id, CustomerReminder: {DispatchType: "Letter"}})

        expect(interface.ensure_customer(subject)).to be(true)
        expect(request).to have_been_requested
      end

      it "returns false if it is another person" do
        stub_get_subject(person.id, status: 200,
          body: remote_subject.merge(FirstName: "Willi").to_json)

        expect(interface.ensure_customer(subject)).to be(false)
        expect(subject.errors).to eq(abacus_subject_key: :taken)
        expect(person.reload.abacus_subject_key).to be_nil
      end

      it "returns false if it has another email" do
        stub_get_subject(person.id, status: 200,
          body: remote_subject.merge(Communications: [{Type: "EMail", Value: "x@example.com"}])
            .to_json)

        expect(interface.ensure_customer(subject)).to be(false)
        expect(subject.errors).to eq(abacus_subject_key: :taken)
      end
    end
  end

  context "with abacus subject key" do
    before { person.update!(abacus_subject_key: 6) }

    it "does nothing if subject and customer exist" do
      stub_get_subject(6, status: 200, body: remote_subject.merge(Id: 6).to_json)

      expect(interface.ensure_customer(subject)).to be(true)
      expect(a_request(:post, /#{api}/)).not_to have_been_made
      expect(person.reload.abacus_subject_key).to eq(6)
    end

    it "creates the customer if missing" do
      stub_get_subject(6, status: 200, body: remote_subject.merge(Id: 6, Customers: []).to_json)
      request = stub_create("Customers",
        {SubjectId: 6, CustomerReminder: {DispatchType: "Letter"}})

      expect(interface.ensure_customer(subject)).to be(true)
      expect(request).to have_been_requested
    end

    it "returns false if the subject does not exist in abacus" do
      stub_get_subject(6, status: 404, body: "{}")

      expect(interface.ensure_customer(subject)).to be(false)
      expect(subject.errors).to eq(abacus_subject_key: :not_found_in_abacus)
      expect(subject.error_messages).to eq(["Abacus Kundennummer wurde in Abacus nicht gefunden"])
    end
  end
end
