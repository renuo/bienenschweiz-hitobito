# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Bienenschweiz::EventInvitationAbility < AbilityDsl::Base
  include AbilityDsl::Constraints::Event::Invitation

  on(Event::Invitation) do
    permission(:layer_events)
      .may(:new, :create, :destroy)
      .in_same_layer_and_invitations_supported
  end
end
