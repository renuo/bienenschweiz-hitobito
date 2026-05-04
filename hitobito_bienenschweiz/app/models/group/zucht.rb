# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Zucht < ::Group
  ### ROLES

  class FachpersonZucht < ::Role
    self.permissions = [:layer_read]
  end

  class FachpersonZuchtInAusbildung < ::Role
    self.permissions = [:layer_read]
  end

  roles FachpersonZucht, FachpersonZuchtInAusbildung
end
