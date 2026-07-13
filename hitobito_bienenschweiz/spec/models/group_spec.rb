# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

require "spec_helper"

describe Group do
  include_examples "group types"

  describe "#canton_short" do
    let(:group) { Fabricate(:sektion) }

    it "returns nil when canton is nil" do
      allow(group).to receive(:canton).and_return(nil)
      expect(group.canton_short).to be_nil
    end

    it "returns upcase canton when canton is set" do
      allow(group).to receive(:canton).and_return("ag")
      expect(group.canton_short).to eq("AG")
    end
  end

  describe "#sorting_name" do
    subject(:sorting_name) { group.sorting_name }

    context "when the group has a code" do
      let(:group) {
        Fabricate(:group, code: 100, name: "Test", type: Group::Kantonalverband.sti_name)
      }

      it "returns the code as a zero-padded string" do
        expect(sorting_name).to eq("000100")
      end
    end

    context "when the group does not have a code" do
      let(:group) {
        Fabricate(:group, code: nil, name: "Test", type: Group::Kantonalverband.sti_name)
      }

      it "returns the display name" do
        expect(sorting_name).to eq("Test")
      end
    end
  end
end
