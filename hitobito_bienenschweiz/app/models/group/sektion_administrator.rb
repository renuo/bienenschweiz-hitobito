# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::SektionAdministrator < ::Group
  ### ROLES

  class AdminSektion < ::Role
    self.permissions = [:layer_and_below_full]
    self.two_factor_authentication_enforced = true
  end

  class ErfassungVeranstaltungen < ::Role
    self.permissions = [:layer_events, :layer_read]
    self.two_factor_authentication_enforced = true
  end

  class Kontakte < ::Role
    self.permissions = [:layer_contacts, :layer_read]
    self.two_factor_authentication_enforced = true
  end

  roles AdminSektion, ErfassungVeranstaltungen, Kontakte
end
