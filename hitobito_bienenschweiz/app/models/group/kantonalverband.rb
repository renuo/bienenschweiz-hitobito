# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Kantonalverband < ::Group
  self.layer = true

  self.event_types = [Event, Event::Course]
  self.default_children = [Group::KantonalverbandAdministrator, Group::KantonalverbandVorstand]
  children Group::Sektion, Group::KantonalverbandAdministrator, Group::KantonalverbandVorstand

  ### ROLES

  roles
end
