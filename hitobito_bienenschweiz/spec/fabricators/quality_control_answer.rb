# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz


Fabricator(:quality_control_answer) do
  deadline_at { 1.week.from_now }
  qcontrol { Fabricate.build(:qcontrol) }
  notes { Faker::Lorem.sentence }
  quality_control_question
end

