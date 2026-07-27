# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::BienenZeitung < ::Group
  ### ROLES

  class Abo < ::Role
    self.permissions = []
  end

  class AboEuro < ::Role
    self.permissions = []
  end

  class GratisAbo < ::Role
    self.permissions = []
  end

  class OnlineAbo < ::Role
    self.permissions = []
  end

  class GeschenkAbo < ::Role
    self.permissions = []
  end

  class BuchhaendlerAbo < ::Role
    self.permissions = []
  end

  roles Abo, AboEuro, GratisAbo, OnlineAbo, GeschenkAbo, BuchhaendlerAbo
end
