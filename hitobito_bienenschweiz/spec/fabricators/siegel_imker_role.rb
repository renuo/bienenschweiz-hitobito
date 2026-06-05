# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

Fabricator(:siegel_imker_role, from: :role) do
  transient :sektion
  type { Group::Siegelimker::Siegelimker.sti_name }
  group { |attrs|
    Fabricate(:group, type: Group::Siegelimker.sti_name,
      parent: attrs[:sektion] || Fabricate(:sektion))
  }
end
