# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Bienenschweiz::GroupAbility do
  subject(:ability) { Ability.new(user) }

  let(:root) { groups(:root) }
  let(:kantonalverband) { groups(:aargauer_kantonalverband) }
  let(:sektion) { groups(:aarau_und_umgebung) }

  describe ":modify_superior (name and code)" do
    context "as AdministratorBienenSchweiz" do
      let(:user) { people(:admin) }

      it "may modify on all layers" do
        expect(ability).to be_able_to(:modify_superior, root)
        expect(ability).to be_able_to(:modify_superior, kantonalverband)
        expect(ability).to be_able_to(:modify_superior, sektion)
        expect(ability).to be_able_to(:modify_superior, groups(:sektion_admin_381))
      end
    end

    context "as Kantonalverband AdminKanton" do
      let(:user) { Fabricate(:person) }
      let(:kv_admin_group) do
        Fabricate(Group::KantonalverbandAdministrator.sti_name, parent: kantonalverband)
      end

      before do
        Fabricate(Group::KantonalverbandAdministrator::AdminKanton.sti_name.to_sym,
          group: kv_admin_group, person: user)
      end

      it "may update but not modify the own layer" do
        expect(ability).to be_able_to(:update, kantonalverband)
        expect(ability).not_to be_able_to(:modify_superior, kantonalverband)
        expect(ability).not_to be_able_to(:modify_superior, kv_admin_group)
      end

      it "may not create or destroy groups" do
        new_group = Group::KantonalverbandVorstand.new(parent: kantonalverband)
        expect(ability).not_to be_able_to(:create, new_group)
        expect(ability).not_to be_able_to(:destroy, kv_admin_group)
      end
    end

    context "as Sektion AdminSektion" do
      let(:user) { Fabricate(:person) }

      before do
        Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: groups(:sektion_admin_381), person: user)
      end

      it "may update but not modify the own layer and its groups" do
        expect(ability).to be_able_to(:update, sektion)
        expect(ability).not_to be_able_to(:modify_superior, sektion)
        expect(ability).not_to be_able_to(:modify_superior, groups(:sektion_admin_381))
      end

      it "may not create or destroy groups" do
        new_group = Group::SektionVorstand.new(parent: sektion)
        expect(ability).not_to be_able_to(:create, new_group)
        expect(ability).not_to be_able_to(:destroy, groups(:sektion_admin_381))
      end
    end
  end

  describe ":create and :destroy" do
    let(:user) { people(:admin) }

    it "are allowed for AdministratorBienenSchweiz" do
      expect(ability).to be_able_to(:create, Group::SektionVorstand.new(parent: sektion))
      expect(ability).to be_able_to(:destroy, groups(:sektion_admin_381))
    end
  end
end
