# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class QcontrolAbility < AbilityDsl::Base
  include AbilityDsl::Constraints::Person

  on(Qcontrol) do
    permission(:layer_and_below_full).may(:read, :checklist, :certificate).all
    permission(:admin).may(:create, :manage_orphans, :destroy).all
  end
end
