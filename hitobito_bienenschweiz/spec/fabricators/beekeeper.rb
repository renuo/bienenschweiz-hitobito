# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

Fabricator(:beekeeper, from: :person) do
  transient :membership_start_on, :membership_end_on, :group_id
  membership_start_on { 1.year.ago }
  membership_end_on { nil }

  after_create do |person, transients|
    Fabricate(:role,
              group_id: transients[:group_id],
              type: Group::Sektion::Siegelimker.sti_name, person:,
              start_on: transients[:membership_start_on], end_on: transients[:membership_end_on])
  end
end

