# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class SiegelimkerProfileAbility < AbilityDsl::Base
  include AbilityDsl::Constraints::Person

  on(SiegelimkerProfile) do
    permission(:any).may(:show, :update).herself
    permission(:layer_full).may(:show, :update).in_same_layer
    permission(:layer_and_below_full).may(:show, :update).in_same_layer_or_below
    permission(:admin).may(:show, :update).all
  end

  def person
    subject.person
  end
end
