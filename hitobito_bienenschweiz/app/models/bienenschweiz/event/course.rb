# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::Event::Course
  extend ActiveSupport::Concern
  prepended do
    self.role_types = [Event::Role::Leader,
      Event::Role::AssistantLeader,
      Event::Role::Helper,
      Event::Role::Speaker,
      Event::Course::Role::Participant]
  end
end
