# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Qcontrol do
  let(:group) { Fabricate(:sektion) }
  let(:person) { Fabricate(:person) }

  describe "#previous_qcontrol" do
    subject(:qcontrol) do
      Fabricate(:qcontrol, person: person, group: group,
        control_date: Date.new(2026, 5, 1), control_state: "passed")
    end

    it "is nil without earlier qcontrols" do
      expect(qcontrol.previous_qcontrol).to be_nil
      expect(qcontrol.first_qcontrol?).to be(true)
    end

    it "returns the latest qcontrol before the control date" do
      Fabricate(:qcontrol, person: person, group: group,
        control_date: Date.new(2026, 6, 1), control_state: "passed")
      previous = Fabricate(:qcontrol, person: person, group: group,
        control_date: Date.new(2024, 4, 1), control_state: "passed")

      expect(qcontrol.previous_qcontrol).to eq(previous)
      expect(qcontrol.first_qcontrol?).to be(false)
    end

    it "is nil for orphan qcontrols" do
      orphan = Fabricate(:qcontrol, person: nil, group: group,
        control_date: Date.new(2026, 5, 1), control_state: "passed")

      expect(orphan.previous_qcontrol).to be_nil
      expect(orphan.first_qcontrol?).to be(true)
    end

    context "when there are previous qcontrols not created in order of date" do
      let(:qcontrol) do
        Fabricate(:qcontrol, person: person, group: group,
          control_date: Date.new(2026, 5, 1), control_state: "passed")
      end
      let(:previous1) do
        Fabricate(:qcontrol, person: person, group: group,
          control_date: Date.new(2024, 4, 1), control_state: "passed")
      end
      let(:previous2) do
        Fabricate(:qcontrol, person: person, group: group,
          control_date: Date.new(2025, 4, 1), control_state: "passed")
      end

      before do
        previous2
        previous1
      end

      it "gives the previous one by control_date" do
        expect(qcontrol.previous_qcontrol).to eq(previous2)
      end
    end
  end

  describe "#update_beekeeper_role" do
    let(:person) { Fabricate(:beekeeper, group_id: group.id) }
    subject(:role) { person.roles.first }

    let(:no_control_reason) { :no_reason }
    let(:qcontrol) do
      Fabricate(:qcontrol, person: person, group: group,
        control_date: Date.new(2026, 5, 1),
        control_state:, no_control_reason:)
    end

    context "when control_state is not_passed" do
      let(:control_state) { "not_passed" }

      it "updates the end_on of the role to 20 days from now" do
        expect {
          qcontrol
        }.to change { role.reload.end_on }.to(Time.zone.today + 20.days)
      end
    end

    context "when control_state is passed" do
      let(:control_state) { "passed" }

      it "does not update end_on" do
        expect {
          qcontrol
        }.not_to change { role.reload.end_on }
      end

      context "when there is a no_control reason" do
        let(:no_control_reason) { :beekeeper_deceased }

        it "updates the end_on of the role to today" do
          expect {
            qcontrol
          }.to change { role.reload.end_on }.to(Time.zone.today)
        end
      end
    end
  end
end
