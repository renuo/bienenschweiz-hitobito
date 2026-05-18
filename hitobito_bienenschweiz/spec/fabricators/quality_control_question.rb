# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz


Fabricator(:quality_control_question) do
  title { "Question #{Faker::Lorem.word}" }
  number { sequence(:number) }
  description { Faker::Lorem.sentence }
  quality_control_section
  inspection_notes { Faker::Lorem.paragraph }
end

