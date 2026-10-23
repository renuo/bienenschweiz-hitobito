# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Bienenschweiz::EventAbility < AbilityDsl::Base
  include AbilityDsl::Constraints::Event
  include AbilityDsl::Constraints::Event::Invitation

  on(Event) do
    permission(:layer_events)
      .may(:index_participations, :index_full_participations, :qualifications_read, :show)
      .in_same_layer
    permission(:layer_events).may(:index_invitations).in_same_layer_and_invitations_supported
    permission(:layer_events)
      .may(:update, :create, :destroy, :application_market, :qualify,
        :create_tags, :assign_tags, :manage_attachments)
      .in_same_layer_if_active

    permission(:layer_and_below_events)
      .may(:index_participations, :index_full_participations, :qualifications_read, :show)
      .in_same_layer_or_below
    permission(:layer_and_below_events)
      .may(:index_invitations).in_same_layer_or_below_and_invitations_supported
    permission(:layer_and_below_events)
      .may(:update, :create, :destroy, :application_market, :qualify,
        :create_tags, :assign_tags, :manage_attachments)
      .in_same_layer_or_below_if_active

    # Core restricts layer_and_below_full to creating/destroying events in the own layer.
    # BienenSchweiz admins act as support for all layers and need to do this everywhere.
    permission(:admin).may(:create, :destroy).at_least_one_group_not_deleted
  end

  private

  def event
    subject
  end
end
