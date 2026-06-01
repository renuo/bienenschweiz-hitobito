# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

Fabricator(:qcontrol) do
  group { Fabricate(:sektion) }
  inspector do |attrs|
    Fabricate(:fachperson_produkte,
      group_id: Fabricate(:group, parent: attrs[:group], type: Group::Produkte.sti_name).id)
  end
  control_date { Date.current }
  with_voucher { false }
end

Fabricator(:due_soon_qcontrol, from: :qcontrol) do
  control_date do
    Faker::Date.between(from: InspectionService::PERIOD.ago,
      to: InspectionService::PERIOD.ago + InspectionService::TIMEFRAME)
  end
end

Fabricator(:recent_qcontrol, from: :qcontrol) do
  control_date do
    Faker::Date.between(from: InspectionService::PERIOD.ago + InspectionService::TIMEFRAME,
      to: Time.zone.today)
  end
end
