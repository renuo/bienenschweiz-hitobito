# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe GroupsHelper, type: :helper do
  describe "#tab_event_participants_label" do
    let(:group) { groups(:aarau_und_umgebung) }

    it "labels the participations tab 'Personen' for courses" do
      course = Fabricate(:course, groups: [group], kind: Fabricate(:event_kind))

      expect(helper.tab_event_participants_label(course)).to eq("Personen")
    end

    it "labels the participations tab 'Personen' for other events" do
      event = Fabricate(:event, groups: [group], kind: Fabricate(:event_kind))

      expect(helper.tab_event_participants_label(event)).to eq("Personen")
    end
  end
end
