# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::Subject do
  let(:person) do
    Fabricate(:person, first_name: "Maja", last_name: "Biene", email: "maja@example.com",
      zip_code: "3000", town: "Bern", language: "de")
  end

  subject(:abacus_subject) { described_class.new(person) }

  describe "#valid?" do
    it "is valid with zip code and town" do
      expect(abacus_subject).to be_valid
    end

    it "requires zip code and town" do
      person.zip_code = nil
      person.town = nil

      expect(abacus_subject).not_to be_valid
      expect(abacus_subject.errors).to eq(town: :blank, zip_code: :blank)
    end
  end

  describe "#subject_attrs" do
    it "sends a company as organisation" do
      person.update!(company: true, company_name: "Imkerei Biene AG")

      expect(abacus_subject.subject_attrs).to eq(
        type: "Organisation", name: "Imkerei Biene AG", salutation_id: 3, language: "de"
      )
    end

    it "uses the divers salutation without gender" do
      expect(abacus_subject.subject_attrs).to include(type: "Person", salutation_id: 36)
    end
  end

  describe "#communication_attrs" do
    it "contains the email" do
      expect(abacus_subject.communication_attrs).to eq([{
        subject_id: 0, type: "EMail", value: "maja@example.com", category: "Private"
      }])
    end

    it "is empty without email" do
      person.email = nil

      expect(abacus_subject.communication_attrs).to eq([])
    end
  end
end
