# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe InspectionReminderJob do
  subject(:job) { InspectionReminderJob.new }

  describe "#perform" do
    it "delegates to InspectionService#deliver_inspection_reminders" do
      service = instance_double(InspectionService)
      allow(InspectionService).to receive(:new).and_return(service)
      expect(service).to receive(:deliver_inspection_reminders)
      job.perform
    end
  end
end
