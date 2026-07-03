# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::KantonalverbandAdministrator < ::Group
  ### ROLES

  class Kontakte < ::Role
    self.permissions = [:layer_contacts, :layer_read]
  end

  class VeranstaltungenKurse < ::Role
    self.permissions = [:layer_events]
  end

  roles Kontakte, VeranstaltungenKurse
end
