# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Zentralvorstand < ::Group
  ### ROLES

  class Zentralpraesident < ::Role
    self.permissions = [:contact_data]
  end

  class Vizepraesident < ::Role
    self.permissions = [:contact_data]
  end

  class Geschaeftsfuehrer < ::Role
    self.permissions = [:contact_data]
  end

  class Mitglied < ::Role
    self.permissions = [:contact_data]
  end

  roles Zentralpraesident, Vizepraesident, Geschaeftsfuehrer, Mitglied
end
