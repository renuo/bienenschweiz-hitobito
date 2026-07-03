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
  end

  private

  def group
    subject
  end
end
