# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe "layer_contacts permission" do
  subject(:ability) { Ability.new(user) }

  let(:user) { Fabricate(:person) }

  # Sektion layer: aarau_und_umgebung
  # Non-layer admin group inside it: sektion_admin_381
  # Sibling sektion in the same kantonalverband: aargauisches_seetal

  context "Group::SektionAdministrator::Kontakte" do
    let(:sektion) { groups(:aarau_und_umgebung) }
    let(:sektion_admin_group) { groups(:sektion_admin_381) }
    let(:other_sektion) { groups(:aargauisches_seetal) }
    let(:other_sektion_admin_group) { groups(:sektion_admin_384) }

    # All non-layer subgroups of aarau_und_umgebung share layer_group_id = sektion.id
    let(:groups_in_layer) do
      [groups(:aarau_und_umgebung), groups(:vorstand_379), groups(:kader_380),
        groups(:sektion_admin_381)]
    end

    before do
      Fabricate(Group::SektionAdministrator::Kontakte.sti_name.to_sym,
        group: sektion_admin_group, person: user)
    end

    context "on people in the same sektion layer" do
      let(:same_layer_role) do
        Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: sektion_admin_group)
      end
      let(:target) { same_layer_role.person.reload }

      it "may show and read details" do
        expect(ability).to be_able_to(:show, target)
        expect(ability).to be_able_to(:show_full, target)
        expect(ability).to be_able_to(:show_details, target)
        expect(ability).to be_able_to(:history, target)
      end

      it "may update and manage" do
        expect(ability).to be_able_to(:update, target)
        expect(ability).to be_able_to(:log, target)
        expect(ability).to be_able_to(:approve_add_request, target)
        expect(ability).to be_able_to(:show_tags, target)
        expect(ability).to be_able_to(:create_tags, target)
        expect(ability).to be_able_to(:assign_tags, target)
        expect(ability).to be_able_to(:index_notes, target)
        expect(ability).to be_able_to(:security, target)
      end

      it "may create new people" do
        expect(ability).to be_able_to(:create, Person)
      end
    end

    context "on roles in the same sektion layer" do
      let(:role_in_layer) do
        Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: sektion_admin_group)
      end

      it "may create, update, and destroy" do
        expect(ability).to be_able_to(:create, role_in_layer)
        expect(ability).to be_able_to(:update, role_in_layer)
        expect(ability).to be_able_to(:destroy, role_in_layer)
      end
    end

    context "on people in a different sektion layer" do
      let(:other_layer_role) do
        Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: other_sektion_admin_group)
      end
      let(:target) { other_layer_role.person.reload }

      it "may not read or update" do
        expect(ability).not_to be_able_to(:show_full, target)
        expect(ability).not_to be_able_to(:update, target)
        expect(ability).not_to be_able_to(:index_notes, target)
      end
    end

    context "on roles in a different sektion layer" do
      let(:role_in_other_layer) do
        Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: other_sektion_admin_group)
      end

      it "may not create, update, or destroy" do
        expect(ability).not_to be_able_to(:create, role_in_other_layer)
        expect(ability).not_to be_able_to(:update, role_in_other_layer)
        expect(ability).not_to be_able_to(:destroy, role_in_other_layer)
      end
    end

    context "on groups in the same sektion layer" do
      it "may index_people on every group in the layer" do
        groups_in_layer.each do |group|
          expect(ability).to be_able_to(:index_people, group)
          expect(ability).to be_able_to(:index_local_people, group)
          expect(ability).to be_able_to(:index_full_people, group)
          expect(ability).to be_able_to(:index_deep_full_people, group)
        end
      end

      it "may not index_people on a group in a different sektion layer" do
        expect(ability).not_to be_able_to(:index_people, other_sektion)
      end

      it "may not index_people on the parent kantonalverband layer" do
        expect(ability).not_to be_able_to(:index_people, groups(:aargauer_kantonalverband))
      end

      it "lists people when fetching the people index for a group in the layer" do
        member = Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: sektion_admin_group)
        readable = PersonReadables.new(user, sektion_admin_group)
        expect(Person.accessible_by(readable)).to include(member.person.reload)
      end
    end

    context "on people at the kantonalverband layer above" do
      let(:kv_role) do
        kv_admin = Fabricate(:group, type: Group::KantonalverbandAdministrator.sti_name,
          parent: groups(:aargauer_kantonalverband))
        Fabricate(Group::KantonalverbandAdministrator::Kontakte.sti_name.to_sym, group: kv_admin)
      end
      let(:target) { kv_role.person.reload }

      it "may not read or update" do
        expect(ability).not_to be_able_to(:show_full, target)
        expect(ability).not_to be_able_to(:update, target)
      end
    end
  end

  context "Group::KantonalverbandAdministrator::Kontakte" do
    let(:kantonalverband) { groups(:aargauer_kantonalverband) }
    let(:kv_admin_group) do
      Fabricate(:group, type: Group::KantonalverbandAdministrator.sti_name,
        parent: kantonalverband)
    end
    let(:kv_vorstand_group) do
      Fabricate(:group, type: Group::KantonalverbandVorstand.sti_name, parent: kantonalverband)
    end
    let(:sektion_in_kv) { groups(:aarau_und_umgebung) }
    let(:other_kantonalverband) { groups(:berner_kantonalverband) }

    before do
      Fabricate(Group::KantonalverbandAdministrator::Kontakte.sti_name.to_sym,
        group: kv_admin_group, person: user)
    end

    context "on people in the same kantonalverband layer" do
      let(:kv_role) do
        kv_vorstand = Fabricate(:group, type: Group::KantonalverbandVorstand.sti_name,
          parent: kantonalverband)
        Fabricate(Group::KantonalverbandVorstand::Praesident.sti_name.to_sym, group: kv_vorstand)
      end
      let(:target) { kv_role.person.reload }

      it "may show and read details" do
        expect(ability).to be_able_to(:show, target)
        expect(ability).to be_able_to(:show_full, target)
        expect(ability).to be_able_to(:show_details, target)
        expect(ability).to be_able_to(:history, target)
      end

      it "may update and manage" do
        expect(ability).to be_able_to(:update, target)
        expect(ability).to be_able_to(:log, target)
        expect(ability).to be_able_to(:show_tags, target)
        expect(ability).to be_able_to(:assign_tags, target)
        expect(ability).to be_able_to(:index_notes, target)
        expect(ability).to be_able_to(:security, target)
      end

      it "may create new people" do
        expect(ability).to be_able_to(:create, Person)
      end
    end

    context "on roles in the same kantonalverband layer" do
      let(:role_in_kv) do
        kv_vorstand = Fabricate(:group, type: Group::KantonalverbandVorstand.sti_name,
          parent: kantonalverband)
        Fabricate(Group::KantonalverbandVorstand::Praesident.sti_name.to_sym, group: kv_vorstand)
      end

      it "may create, update, and destroy" do
        expect(ability).to be_able_to(:create, role_in_kv)
        expect(ability).to be_able_to(:update, role_in_kv)
        expect(ability).to be_able_to(:destroy, role_in_kv)
      end
    end

    context "on groups in the same kantonalverband layer" do
      it "may index_people on every group in the layer" do
        [kantonalverband, kv_admin_group, kv_vorstand_group].each do |group|
          expect(ability).to be_able_to(:index_people, group)
          expect(ability).to be_able_to(:index_local_people, group)
          expect(ability).to be_able_to(:index_full_people, group)
          expect(ability).to be_able_to(:index_deep_full_people, group)
        end
      end

      it "may not index_people on a child sektion layer" do
        expect(ability).not_to be_able_to(:index_people, sektion_in_kv)
      end

      it "may not index_people on a different kantonalverband" do
        expect(ability).not_to be_able_to(:index_people, other_kantonalverband)
      end

      it "lists people when fetching the people index for a group in the layer" do
        member = Fabricate(Group::KantonalverbandAdministrator::Kontakte.sti_name.to_sym,
          group: kv_admin_group)
        readable = PersonReadables.new(user, kv_admin_group)
        expect(Person.accessible_by(readable)).to include(member.person.reload)
      end
    end

    context "on people in a sektion layer below the kantonalverband" do
      let(:sektion_role) do
        Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: groups(:sektion_admin_381))
      end
      let(:target) { sektion_role.person.reload }

      it "may not read or update (layer_contacts does not include below)" do
        expect(ability).not_to be_able_to(:show_full, target)
        expect(ability).not_to be_able_to(:update, target)
      end
    end

    context "on people in a different kantonalverband layer" do
      let(:other_kv_role) do
        kv_admin = Fabricate(:group, type: Group::KantonalverbandAdministrator.sti_name,
          parent: other_kantonalverband)
        Fabricate(Group::KantonalverbandAdministrator::Kontakte.sti_name.to_sym, group: kv_admin)
      end
      let(:target) { other_kv_role.person.reload }

      it "may not read or update" do
        expect(ability).not_to be_able_to(:show_full, target)
        expect(ability).not_to be_able_to(:update, target)
      end
    end

    context "on roles in a different kantonalverband layer" do
      let(:role_in_other_kv) do
        kv_admin = Fabricate(:group, type: Group::KantonalverbandAdministrator.sti_name,
          parent: other_kantonalverband)
        Fabricate(Group::KantonalverbandAdministrator::Kontakte.sti_name.to_sym, group: kv_admin)
      end

      it "may not create, update, or destroy" do
        expect(ability).not_to be_able_to(:create, role_in_other_kv)
        expect(ability).not_to be_able_to(:update, role_in_other_kv)
        expect(ability).not_to be_able_to(:destroy, role_in_other_kv)
      end
    end
  end
end
