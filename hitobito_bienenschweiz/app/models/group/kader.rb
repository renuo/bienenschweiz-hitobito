# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::Kader < ::Group
  ### ROLES

  class FachpersonBildung < ::Role
    self.permissions = [:contact_data, :layer_read]
  end

  class FachpersonProdukte < ::Role
    self.permissions = [:contact_data, :layer_read]
  end

  class FachpersonZuchtVermehrung < ::Role
    self.permissions = [:contact_data, :layer_read]
  end

  roles FachpersonBildung, FachpersonProdukte, FachpersonZuchtVermehrung
end
