# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class ReplaceSektionMitgliederMitgliedWithAktivmitgliedAndPassivmitglied < ActiveRecord::Migration[7.1]
  def up
    Role.where(type: "Group::SektionMitglieder::Mitglied")
      .update_all(type: "Group::SektionMitglieder::Aktivmitglied")
  end

  def down
    Role.where(type: "Group::SektionMitglieder::Aktivmitglied")
      .update_all(type: "Group::SektionMitglieder::Mitglied")
    Role.where(type: "Group::SektionMitglieder::Passivmitglied")
      .update_all(type: "Group::SektionMitglieder::Mitglied")
  end
end
