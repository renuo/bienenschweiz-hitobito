# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::PersonReadables
  private

  def read_permission_for_this_group?
    super || permission_layer_ids(:layer_contacts).include?(group.layer_group_id)
  end
end
