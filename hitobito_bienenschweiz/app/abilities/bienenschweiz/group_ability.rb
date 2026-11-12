# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Bienenschweiz::GroupAbility < AbilityDsl::Base
  include AbilityDsl::Constraints::Group

  on(Group) do
    permission(:layer_contacts)
      .may(:index_people, :index_local_people, :index_full_people, :index_deep_full_people)
      .in_same_layer

    permission(:layer_events)
      .may(:index_events, :"index_event/courses", :export_events, :"export_event/courses")
      .in_same_layer
    permission(:layer_and_below_events)
      .may(:index_events, :"index_event/courses", :export_events, :"export_event/courses")
      .in_same_layer_or_below

    general(:index_person_add_requests,
      :activate_person_add_requests,
      :deactivate_person_add_requests).none

    # Abos (mailing lists) are managed centrally on the Dachverband only.
    general(:index_mailing_lists).if_dachverband

    # Groups are static (imported during data migration), so only admins may create or
    # destroy them. Likewise, name and code (superior_attributes) may only be changed by
    # admins. Core grants these to e.g. :layer_full/:layer_and_below_full; the general
    # constraints restrict that.
    permission(:admin).may(:modify_superior).all
    general(:create, :destroy, :modify_superior).if_admin
  end

  def if_dachverband
    group.is_a?(Group::Dachverband)
  end

  private

  def group
    subject
  end
end
