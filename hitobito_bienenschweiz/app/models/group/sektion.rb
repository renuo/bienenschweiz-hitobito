# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Sektion < ::Group
  self.layer = true

  self.event_types = [Event, Event::Course]

  self.default_children = [Group::Bildung, Group::Produkte, Group::Zucht]

  children Group::Bildung, Group::Produkte, Group::Zucht

  ### ROLES

  class AdminSektion < ::Role
    self.permissions = [:layer_and_below_full]
  end

  class Praesident < ::Role
    self.permissions = [:layer_and_below_full, :contact_data]
  end

  class Kassier < ::Role
    self.permissions = [:layer_read, :contact_data]
  end

  class ErfassungVeranstaltungen < ::Role
    self.permissions = [:layer_read]
  end

  class Siegelimker < ::Role
    self.permissions = [:layer_read]
  end

  class SiegelimkerProvisorisch < ::Role
    self.permissions = [:layer_read]
  end

  roles AdminSektion, Praesident, Kassier, ErfassungVeranstaltungen, Siegelimker,
    SiegelimkerProvisorisch
end
