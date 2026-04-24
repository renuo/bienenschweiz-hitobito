# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Verband < ::Group
  self.layer = true

  children Group::Sektion

  ### ROLES

  class Bildungsobperson < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  class Honigobperson < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  class HonigobpersonProvisorisch < ::Role
    self.permissions = [:group_read]
  end

  class Zuchtobperson < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  class Kantonalpraesidentin < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  class Kassier < ::Role
    self.permissions = [:group_read]
  end

  roles Bildungsobperson, Honigobperson, HonigobpersonProvisorisch, Zuchtobperson,
    Kantonalpraesidentin, Kassier
end
