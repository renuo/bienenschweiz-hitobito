# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

class Group::KantonalverbandVorstand < ::Group
  ### ROLES

  class Bildung < ::Role
    self.permissions = [:contact_data, :layer_and_below_read]
  end

  class Produkte < ::Role
    self.permissions = [:contact_data, :layer_and_below_read]
  end

  class Zucht < ::Role
    self.permissions = [:contact_data, :layer_and_below_read]
  end

  class Praesident < ::Role
    self.permissions = [:contact_data, :layer_and_below_read]
  end

  class Vizepraesident < ::Role
    self.permissions = [:contact_data, :layer_and_below_read]
  end

  class Kassier < ::Role
    self.permissions = [:contact_data, :layer_and_below_read]
  end

  class Aktuar < ::Role
    self.permissions = [:contact_data, :layer_and_below_read]
  end

  class Beisitzer < ::Role
    self.permissions = [:contact_data, :layer_and_below_read]
  end

  roles Bildung, Produkte, Zucht, Praesident, Vizepraesident, Kassier, Aktuar, Beisitzer
end
