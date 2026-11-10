# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Zentralvorstand < ::Group
  ### ROLES

  class Praesident < ::Role
    self.permissions = [:layer_and_below_read]
  end

  class Vizepraesident < ::Role
    self.permissions = [:layer_and_below_read]
  end

  class Finanzen < ::Role
    self.permissions = [:layer_and_below_read]
  end

  class Beisitzer < ::Role
    self.permissions = [:layer_and_below_read]
  end

  roles Praesident, Vizepraesident, Finanzen, Beisitzer
end
