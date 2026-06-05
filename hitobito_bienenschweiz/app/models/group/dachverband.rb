# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Dachverband < ::Group
  self.layer = true

  self.event_types = [Event, Event::Course]

  self.default_children = [Group::Mitglieder, Group::Zentralvorstand, Group::Shop,
    Group::BienenZeitung, Group::ThemenbezogeneKontakte]

  children Group::Kantonalverband, Group::Mitglieder, Group::Zentralvorstand, Group::Shop,
    Group::BienenZeitung, Group::ThemenbezogeneKontakte

  ### ROLES

  class AdministratorBienenSchweiz < ::Role
    self.permissions = [:admin, :layer_and_below_full]
  end

  roles AdministratorBienenSchweiz
end
