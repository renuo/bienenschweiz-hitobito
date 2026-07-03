# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Bienenschweiz::EventRoleAbility < AbilityDsl::Base
  include AbilityDsl::Constraints::Event

  on(Event::Role) do
    permission(:layer_events).may(:manage).in_same_layer_if_active
  end

  private

  def event
    subject.participation.event
  end
end
