# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::SektionMitglieder < ::Group
  ### ROLES

  class Ehrenmitglied < ::Role
    self.permissions = []
  end

  class Freimitglied < ::Role
    self.permissions = []
  end

  class Veteranen < ::Role
    self.permissions = []
  end

  class Aktivmitglied < ::Role
    self.permissions = []
  end

  class Passivmitglied < ::Role
    self.permissions = []
  end

  roles Ehrenmitglied, Freimitglied, Veteranen, Aktivmitglied, Passivmitglied
end
