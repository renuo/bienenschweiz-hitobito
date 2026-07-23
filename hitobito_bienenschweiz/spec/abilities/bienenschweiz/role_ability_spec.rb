# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe "beekeeper role modification restriction" do
  subject(:ability) { Ability.new(user) }

  let(:user) { Fabricate(:person) }
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:sektion_admin_group) { groups(:sektion_admin_381) }
  let(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion:) }

  context "Group::Dachverband::AdministratorBienenSchweiz" do
    before do
      Fabricate(Group::Dachverband::AdministratorBienenSchweiz.sti_name.to_sym,
        group: groups(:root), person: user)
    end

    it "may create, update, and destroy beekeeper roles" do
      expect(ability).to be_able_to(:create, beekeeper_role)
      expect(ability).to be_able_to(:update, beekeeper_role)
      expect(ability).to be_able_to(:destroy, beekeeper_role)
    end
  end

  context "Group::SektionAdministrator::AdminSektion" do
    before do
      Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
        group: sektion_admin_group, person: user)
    end

    it "may not create, update, or destroy beekeeper roles, despite layer_and_below_full" do
      expect(ability).not_to be_able_to(:create, beekeeper_role)
      expect(ability).not_to be_able_to(:update, beekeeper_role)
      expect(ability).not_to be_able_to(:destroy, beekeeper_role)
    end

    it "may still create, update, and destroy other roles in the same layer" do
      other_role = Fabricate(Group::SektionAdministrator::Kontakte.sti_name.to_sym,
        group: sektion_admin_group)

      expect(ability).to be_able_to(:create, other_role)
      expect(ability).to be_able_to(:update, other_role)
      expect(ability).to be_able_to(:destroy, other_role)
    end
  end

  context "Group::SektionAdministrator::Kontakte" do
    before do
      Fabricate(Group::SektionAdministrator::Kontakte.sti_name.to_sym,
        group: sektion_admin_group, person: user)
    end

    it "may not create, update, or destroy beekeeper roles, despite layer_contacts" do
      expect(ability).not_to be_able_to(:create, beekeeper_role)
      expect(ability).not_to be_able_to(:update, beekeeper_role)
      expect(ability).not_to be_able_to(:destroy, beekeeper_role)
    end
  end
end
