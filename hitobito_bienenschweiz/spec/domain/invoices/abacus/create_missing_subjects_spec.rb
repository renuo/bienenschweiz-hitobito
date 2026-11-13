# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Invoices::Abacus::CreateMissingSubjects do
  let(:group) { groups(:root) }
  let(:role_type) { Group::Dachverband::AdministratorBienenSchweiz.sti_name }

  def end_roles(person)
    Role.with_inactive.where(person:).update_all(end_on: Date.yesterday) # rubocop:disable Rails/SkipsModelValidations
  end

  describe ".people" do
    let!(:with_role) { Fabricate(:role, type: role_type, group:).person }
    let!(:with_subscription) do
      Fabricate(:magazine_subscription).person.tap { |person| end_roles(person) }
    end
    let!(:with_ended_role) do
      Fabricate(:role, type: role_type, group:).person.tap { |person| end_roles(person) }
    end
    let!(:with_ended_subscription) do
      Fabricate(:magazine_subscription, start_date: 2.years.ago, end_date: 1.year.ago,
        cancellation_reason: "biwe")
        .person.tap { |person| end_roles(person) }
    end
    let!(:linked) do
      Fabricate(:role, type: role_type, group:).person
        .tap { |person| person.update!(abacus_subject_key: 4711) }
    end
    let!(:without_anything) { Fabricate(:person) }

    it "includes unlinked people with an active role or subscription" do
      people = described_class.people

      expect(people).to include(with_role, with_subscription)
      expect(people).not_to include(with_ended_role, with_ended_subscription, linked,
        without_anything)
    end
  end

  describe "#run" do
    let(:ok) { Fabricate(:role, type: role_type, group:).person }
    let(:invalid) { Fabricate(:role, type: role_type, group:).person }
    let(:broken) { Fabricate(:role, type: role_type, group:).person }
    let(:interface) { instance_double(Invoices::Abacus::SubjectInterface) }
    let(:log) { [] }

    before do
      allow(described_class).to receive(:people)
        .and_return(Person.where(id: [ok, invalid, broken]))
      allow(Invoices::Abacus::SubjectInterface).to receive(:new).and_return(interface)
      allow(interface).to receive(:ensure_customer) do |subject|
        case subject.entity
        when ok then true
        when invalid
          subject.errors[:town] = :blank
          false
        when broken then raise RestClient::InternalServerError
        end
      end
    end

    it "creates the subjects and collects the failures" do
      result = described_class.new(client: double, logger: log.method(:<<)).run

      expect(result.created).to eq([ok])
      expect(result.failed.keys).to contain_exactly(invalid, broken)
      expect(result.failed[invalid]).to include("Ort")
      expect(result.failed[broken]).to eq("Internal Server Error")
      expect(log.size).to eq(3)
    end
  end
end
