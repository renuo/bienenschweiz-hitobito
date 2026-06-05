# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Sektion < ::Group
  self.layer = true

  self.event_types = [Event, Event::Course]

  self.default_children = [
    Group::Siegelimker, Group::SektionAdministrator, Group::SektionMitglieder,
    Group::SektionVorstand, Group::Kader
  ]

  children Group::Siegelimker, Group::SektionAdministrator, Group::SektionMitglieder,
    Group::SektionVorstand, Group::Kader

  ### ROLES

  class AdminSektion < ::Role
    self.permissions = [:layer_and_below_full]
  end

  roles AdminSektion
end
