# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

# TODO: rename class to specific name and change all references
class Group::Root < ::Group
  self.layer = true

  # TODO: define actual child group types
  children Group::Verband

  ### ROLES

  # TODO: define actual role types
  class AdministratorBienenSchweiz < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  # TODO: figure out actual permissions
  class Ehrenmitglied < ::Role
    self.permissions = [:group_read]
  end

  class Ehrenpraesident < ::Role
    self.permissions = [:group_read]
  end

  class ErfassungVeranstaltungen < ::Role
    self.permissions = [:group_read]
  end

  class Mitglied < ::Role
    self.permissions = [:group_read]
  end

  class Supervisor < ::Role
    self.permissions = [:group_read]
  end

  roles AdministratorBienenSchweiz, Ehrenmitglied, Ehrenpraesident, ErfassungVeranstaltungen,
    Mitglied, Supervisor
end
