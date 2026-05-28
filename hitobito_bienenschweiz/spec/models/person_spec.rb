# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Person do
  describe "#inspectable_groups" do
    let(:person) { Fabricate(:person) }
    let(:inspector_role) { create :inspector_role }
    let(:honey_chairman_role) { create :honey_chairman_role }
    let(:siegel_imker_role) { create :siegel_imker_role }
    let(:verband) { groups(:aargauer_kantonalverband) }

    context "without any roles" do
      it "returns an empty list" do
        expect(person.inspectable_groups).to be_empty
      end
    end

    context "with one active role as an inspector" do
      let(:group) { groups(:produkte_380) }
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

    # TODO: cleanup before merge
    # We no longer have this case as the role type is restricted by group type
    # context 'with one active role not in a verband' do
    #   let(:intern_structure) { create :verein }
    #   let!(:role) { create(:role, person: person, role: inspector_role, intern_structure:) }
    #   it 'returns that intern structure' do
    #     expect(person.inspectable_groups).to be_empty
    #   end
    # end
    #
    # context 'with one active role not in a sektion that has a section child' do
    #   let!(:child_section) { create :section, parent: intern_structure }
    #   let(:intern_structure) { create :verein }
    #   let!(:role) { create(:role, person: person, role: inspector_role, intern_structure:) }
    #   it 'returns that intern structure' do
    #     expect(person.inspectable_groups).to contain_exactly(child_section)
    #   end
    # end

    context "with multiple roles as both inspector and chairman" do
      let(:group) { groups(:produkte_380) }
      let(:person) { Fabricate(:fachperson_produkte, group_id: group.id) }
      let(:other_verband) { Fabricate(:kantonalverband) }
      let!(:other_sektion) { Fabricate(:sektion, parent: other_verband, name: "AAA") }
      let!(:chairman_role) {
        Fabricate(:role,
          group_id: other_verband.id,
          type: Group::Kantonalverband::Honigobperson, person:)
      }

      it "returns the intern structure from the inspector role first" do
        expect(person.inspectable_groups).to match_array([group.parent, other_sektion])
      end
    end

    context "with multiple active roles as inspector" do
      let(:group) { groups(:produkte_380) }
      let(:other_produkte_group) { groups(:produkte_602) }
      let(:person) { Fabricate(:fachperson_produkte, group_id: group.id) }

      let!(:other_inspector_role) {
        Fabricate(:role,
          group_id: other_produkte_group.id,
          type: Group::Produkte::FachpersonProdukte, person:)
      }
      let(:other_verband) { Fabricate(:kantonalverband) }
      let!(:other_sektion) { Fabricate(:sektion, parent: other_verband, name: "AAA") }
      let!(:chairman_role) {
        Fabricate(:role,
          group_id: other_verband.id,
          type: Group::Kantonalverband::Honigobperson, person:)
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
      let(:group) { groups(:produkte_380) }
      let(:sektion) { groups(:aarau_und_umgebung) }
      let(:person) { Fabricate(:fachperson_produkte, group_id: group.id) }

      it "returns Sektion of that group in beeaudit structure" do
        expect(person.inspectable_intern_structures).to eq([{
          "id" => sektion.id,
          "name" => sektion.name,
          "structure_type" => "sektion",
          "kanton" => sektion.canton
        }])
      end
    end
  end

  describe "#inspectable_beekeepers" do
    let(:beekeepers) { Fabricate.times(6, :person) }
    let(:aargau_canton) { groups(:aargauer_kantonalverband) }
    let(:bern_canton) { groups(:berner_kantonalverband) }
    let(:aarau) { groups(:aarau_und_umgebung) }
    let(:aarau_produkte) { groups(:produkte_380) }
    let(:seetal) { groups(:aargauisches_seetal) }
    let(:aarberg) { groups(:aarberg) }
    let(:bern_mittelland) { groups(:bern_mittelland) }
    let(:aarau_inspector) do
      Fabricate(:fachperson_produkte, group_id: aarau_produkte.id, last_name: "Inspektor")
    end
    let(:bern_inspector) do
      Fabricate(:honey_chairman, group_id: bern_canton.id)
    end

    before do
      Fabricate(:siegel_imker_role, person: beekeepers[0], group: aarau)
      Fabricate(:siegel_imker_role, person: beekeepers[1], group: seetal)
      Fabricate(:siegel_imker_role, person: beekeepers[2], group: aarberg)
      Fabricate(:siegel_imker_role, person: beekeepers[3], group: bern_mittelland)
      Fabricate(:siegel_imker_role, person: beekeepers[4], group: seetal, start_on: 1.day.from_now)
      Fabricate(:siegel_imker_role, person: beekeepers[5], group: aarau, end_on: 1.day.ago)
      Fabricate(:siegel_imker_role, person: aarau_inspector, group: aarau)
    end

    it "contains the beekeepers from the same group as inspector including himself" do
      expect(aarau_inspector.inspectable_beekeepers).to contain_exactly(beekeepers[0],
        aarau_inspector)
    end

    it "contains the beekeepers within the intern_structure that the inspector has" do
      expect(bern_inspector.inspectable_beekeepers).to contain_exactly(beekeepers[2], beekeepers[3])
    end
  end
end
