# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Sektion < ::Group
  self.layer = true

  ### ROLES

  class FachpersonBildung < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  class FachpersonBildungInAusbildung < ::Role
    self.permissions = [:group_read]
  end

  class FachpersonProdukte < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  class FachpersonProdukteInAusbildung < ::Role
    self.permissions = [:group_read]
  end

  class Kassier < ::Role
    self.permissions = [:group_read]
  end

  class Siegelimker < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  class SiegelimkerProvisorisch < ::Role
    self.permissions = [:group_read]
  end

  class FachpersonZucht < ::Role
    self.permissions = [:layer_and_below_full, :admin]
  end

  class FachpersonZuchtInAusbildung < ::Role
    self.permissions = [:group_read]
  end

  roles FachpersonBildung, FachpersonBildungInAusbildung, FachpersonProdukte,
    FachpersonProdukteInAusbildung, Kassier, Siegelimker, SiegelimkerProvisorisch,
    FachpersonZucht, FachpersonZuchtInAusbildung
end
