# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::EventsController
  def load_sister_groups
    if group.is_a?(Group::Sektion)
      @groups = Group::Sektion.all.reorder(:code)
    else
      master = @event.groups.first
      @groups = master.self_and_sister_groups.reorder(:name)
    end
    # union to include assigned deleted events
    @groups = (@groups | @event.groups)
  end
end
