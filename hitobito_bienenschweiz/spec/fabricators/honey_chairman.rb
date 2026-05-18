# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

Fabricator(:honey_chairman, from: :person) do
  transient :group_id

  after_create do |person, transients|
    Fabricate(:role,
              group_id: transients[:group_id],
              type: Group::Kantonalverband::Honigobperson.sti_name, person:)
  end
end

