# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Bienenschweiz::EventParticipationAbility < AbilityDsl::Base
  include AbilityDsl::Constraints::Event
  include AbilityDsl::Constraints::Event::Participation

  on(Event::Participation) do
    permission(:layer_events)
      .may(:show, :show_details, :show_full, :print, :update)
      .in_same_layer_or_different_prio
    permission(:layer_events)
      .may(:create, :destroy, :send_mails)
      .in_same_layer_if_active
  end

  private

  def participation
    subject
  end
end
