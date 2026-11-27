# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe "Two factor authentication enforcement" do
  let(:enforced_group_types) do
    [
      Group::KantonalverbandVorstand,
      Group::KantonalverbandAdministrator,
      Group::SektionVorstand,
      Group::Fachpersonen,
      Group::SektionAdministrator,
      Group::Zentralvorstand
    ]
  end

  let(:enforced_single_roles) do
    [
      Group::Dachverband::AdministratorBienenSchweiz,
      Group::ThemenbezogeneKontakte::Supervisor,
      Group::Apiservice::VeranstaltungenKurse
    ]
  end

  it "enforces 2FA exactly for the roles of the board, admin and specialist groups" do
    enforced = Role.all_types.select(&:two_factor_authentication_enforced)

    expect(enforced).to match_array(
      enforced_group_types.flat_map(&:role_types) + enforced_single_roles
    )
  end

  it "requires a second factor for a person with an enforced role" do
    person = Fabricate(:person)
    Fabricate(:role, group: groups(:vorstand_379), person:,
      type: Group::SektionVorstand::Kassier.sti_name)

    expect(person.reload.second_factor_required?).to be true
  end

  it "does not require a second factor for a regular member" do
    person = Fabricate(:person)
    mitglieder = Fabricate(:group, type: Group::SektionMitglieder.sti_name,
      parent: groups(:aarau_und_umgebung))
    Fabricate(:role, group: mitglieder, person:,
      type: Group::SektionMitglieder::Aktivmitglied.sti_name)

    expect(person.reload.second_factor_required?).to be false
  end
end
