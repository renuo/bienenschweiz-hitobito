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

  describe "#member_count" do
    context "for a Sektion" do
      it "returns the manually entered value" do
        expect(Fabricate(:sektion, member_count: 42).member_count).to eq(42)
      end

      it "returns nil when not set" do
        expect(Fabricate(:sektion).member_count).to be_nil
      end
    end

    context "for a Kantonalverband" do
      let(:kantonalverband) { groups(:aargauer_kantonalverband) }

      it "sums member_count across its descendant Sektionen" do
        groups(:aarau_und_umgebung).update!(member_count: 10)
        groups(:aargauisches_seetal).update!(member_count: 5)

        expect(kantonalverband.member_count).to eq(15)
      end

      it "treats Sektionen without a count as zero" do
        groups(:aarau_und_umgebung).update!(member_count: 10)
        groups(:aargauisches_seetal).update!(member_count: nil)

        expect(kantonalverband.member_count).to eq(10)
      end
    end

    context "for a Dachverband" do
      it "sums member_count across all descendant Sektionen, regardless of depth" do
        groups(:aarau_und_umgebung).update!(member_count: 10)
        groups(:aarberg).update!(member_count: 7)

        expect(groups(:root).member_count).to eq(17)
      end
    end

    context "for a non-layer group" do
      it "returns nil" do
        expect(groups(:vorstand_379).member_count).to be_nil
      end
    end
  end

  describe "member_count validation" do
    it "is valid when set on a Sektion" do
      expect(Fabricate.build(:sektion, member_count: 5)).to be_valid
    end

    it "is invalid when set on a non-Sektion group" do
      group = Fabricate.build(:group, type: Group::Kantonalverband.sti_name,
        parent: groups(:root), member_count: 5)

      expect(group).not_to be_valid
      expect(group.errors[:member_count]).to include("kann nur für Sektionen gesetzt werden")
    end

    it "rejects negative values" do
      expect(Fabricate.build(:sektion, member_count: -1)).not_to be_valid
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
