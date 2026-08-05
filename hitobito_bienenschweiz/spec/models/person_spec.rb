# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Person do
  describe "#inspectable_groups" do
    let(:person) { Fabricate(:person) }
    let(:verband) { groups(:aargauer_kantonalverband) }

    context "without any roles" do
      it "returns an empty list" do
        expect(person.inspectable_groups).to be_empty
      end
    end

    context "with one active role as an inspector" do
      let(:group) { groups(:kader_380) }
      let(:person) { Fabricate(:fachperson_produkte, group_id: group.id) }

      it "returns Sektion of that group" do
        expect(person.inspectable_groups).to contain_exactly(group.parent)
      end
    end

    context "with one active role not as an inspector" do
      let(:group) { groups(:aarau_und_umgebung) }
      let(:person) { Fabricate(:beekeeper, group_id: group.id) }

      it "returns that intern structure" do
        expect(person.inspectable_groups).to be_empty
      end
    end

    context "with multiple roles as both inspector and chairman" do
      let(:group) { groups(:kader_380) }
      let(:person) { Fabricate(:fachperson_produkte, group_id: group.id) }
      let(:other_verband) { Fabricate(:kantonalverband) }
      let!(:other_sektion) { Fabricate(:sektion, parent: other_verband, name: "AAA") }
      let!(:chairman_role) {
        kv_vorstand = Fabricate(:group, type: Group::KantonalverbandVorstand.sti_name,
          parent: other_verband)
        Fabricate(:role, group_id: kv_vorstand.id,
          type: Group::KantonalverbandVorstand::Produkte.sti_name, person:)
      }

      it "returns the intern structure from the inspector role first" do
        expect(person.inspectable_groups).to match_array([group.parent, other_sektion])
      end
    end

    context "with multiple active roles as inspector" do
      let(:group) { groups(:kader_380) }
      let(:other_kader_group) { groups(:kader_602) }
      let(:person) { Fabricate(:fachperson_produkte, group_id: group.id) }

      let!(:other_inspector_role) {
        Fabricate(:role,
          group_id: other_kader_group.id,
          type: Group::Kader::FachpersonProdukte, person:)
      }
      let(:other_verband) { Fabricate(:kantonalverband) }
      let!(:other_sektion) { Fabricate(:sektion, parent: other_verband, name: "AAA") }
      let!(:chairman_role) {
        kv_vorstand = Fabricate(:group, type: Group::KantonalverbandVorstand.sti_name,
          parent: other_verband)
        Fabricate(:role, group_id: kv_vorstand.id,
          type: Group::KantonalverbandVorstand::Produkte.sti_name, person:)
      }

      it "returns the intern structure from the inspector role first" do
        expect(person.inspectable_groups).to match_array([group.parent,
          other_inspector_role.group.parent,
          other_sektion])
      end
    end
  end

  describe "#inspectable_intern_structures" do
    context "with one active role as an inspector" do
      let(:group) { groups(:kader_380) }
      let(:sektion) { groups(:aarau_und_umgebung) }
      let(:person) { Fabricate(:fachperson_produkte, group_id: group.id) }

      it "returns Sektion of that group in beeaudit structure" do
        expect(person.inspectable_intern_structures).to eq([{
          "id" => sektion.id,
          "name" => sektion.name,
          "structure_type" => "sektion",
          "kanton" => sektion.canton_short
        }])
      end
    end
  end

  describe "#address_affixes" do
    it "returns empty array when address_care_of is nil" do
      person = Fabricate(:person, address_care_of: nil)
      expect(person.address_affixes).to eq([])
    end

    it "returns split parts when address_care_of is set" do
      person = Fabricate(:person, address_care_of: "c/o Müller, Appartement 3")
      expect(person.address_affixes).to eq(["c/o Müller", "Appartement 3"])
    end
  end

  describe "#telephone" do
    it "returns nil when no private phone number exists" do
      person = Fabricate(:person)
      expect(person.telephone).to be_nil
    end

    it "returns the number when a private phone number exists" do
      person = Fabricate(:person)
      Fabricate(:phone_number, contactable: person, label: "private", number: "+41 31 123 45 67")
      expect(person.telephone).to eq("+41 31 123 45 67")
    end
  end

  describe "#mobile" do
    it "returns nil when no mobile phone number exists" do
      person = Fabricate(:person)
      expect(person.mobile).to be_nil
    end

    it "returns the number when a mobile phone number exists" do
      person = Fabricate(:person)
      Fabricate(:phone_number, contactable: person, label: "mobile", number: "+41 79 123 45 67")
      expect(person.mobile).to eq("+41 79 123 45 67")
    end
  end

  describe "#canton_short" do
    let(:person) { Fabricate(:person) }

    it "returns nil when canton is nil" do
      allow(person).to receive(:canton).and_return(nil)
      expect(person.canton_short).to be_nil
    end

    it "returns upcase canton code when canton is set" do
      allow(person).to receive(:canton).and_return("be")
      expect(person.canton_short).to eq("BE")
    end
  end

  describe "#inspectable_beekeepers" do
    let(:beekeepers) { Fabricate.times(6, :person) }
    let(:aargau_canton) { groups(:aargauer_kantonalverband) }
    let(:bern_canton) { groups(:berner_kantonalverband) }
    let(:aarau) { groups(:aarau_und_umgebung) }
    let(:aarau_kader) { groups(:kader_380) }
    let(:seetal) { groups(:aargauisches_seetal) }
    let(:aarberg) { groups(:aarberg) }
    let(:bern_mittelland) { groups(:bern_mittelland) }
    let(:aarau_inspector) do
      Fabricate(:fachperson_produkte, group_id: aarau_kader.id, last_name: "Inspektor")
    end
    let(:bern_inspector) do
      Fabricate(:honey_chairman, group_id: bern_canton.id)
    end

    before do
      Fabricate(:siegel_imker_role, person: beekeepers[0], sektion: aarau)
      Fabricate(:siegel_imker_role, person: beekeepers[1], sektion: seetal)
      Fabricate(:siegel_imker_role, person: beekeepers[2], sektion: aarberg)
      Fabricate(:siegel_imker_role, person: beekeepers[3], sektion: bern_mittelland)
      Fabricate(:siegel_imker_role, person: beekeepers[4], sektion: seetal,
        start_on: 1.day.from_now)
      Fabricate(:siegel_imker_role, person: beekeepers[5], sektion: aarau, end_on: 1.day.ago)
      Fabricate(:siegel_imker_role, person: aarau_inspector, sektion: aarau)
    end

    it "contains the beekeepers from the same group as inspector including himself" do
      expect(aarau_inspector.inspectable_beekeepers).to contain_exactly(beekeepers[0],
        aarau_inspector)
    end

    it "contains the beekeepers within the intern_structure that the inspector has" do
      expect(bern_inspector.inspectable_beekeepers).to contain_exactly(beekeepers[2], beekeepers[3])
    end
  end

  describe "gender" do
    let(:person) { Fabricate(:person) }

    it "allows divers as gender" do
      person.gender = "d"
      expect(person).to be_valid
      expect(person.gender_label).to eq("divers")
    end

    it "offers divers as an option" do
      expect(Person::GENDERS).to include("d")
      expect(Person.gender_labels).to include(d: "divers")
    end

    it "converts the translated value to divers" do
      person.gender = "divers"
      expect(person.gender).to eq("d")
    end
  end
end
