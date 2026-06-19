# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe GroupInspectionReminder do
  let(:kantonalverband) { Fabricate(:kantonalverband) }
  let(:sektion) { Fabricate(:sektion, parent: kantonalverband, name: "Testsektion") }
  let(:kader_group) { Fabricate(:group, type: Group::Kader.sti_name, parent: sektion) }
  let(:inspector_person) { Fabricate(:person) }
  let!(:inspector_role) do
    Fabricate(:role, person: inspector_person, group: kader_group,
      type: Group::Kader::FachpersonProdukte.sti_name)
  end
  let(:inspectors) { Person.where(id: inspector_person.id) }

  subject(:reminder) { GroupInspectionReminder.new(sektion, inspectors) }

  describe "#inspector_emails" do
    it "returns the inspector email" do
      expect(reminder.inspector_emails).to eq([inspector_person.email])
    end

    it "excludes inspectors without an email" do
      inspector_person.update!(email: nil)
      expect(reminder.inspector_emails).to be_empty
    end
  end

  describe "#president_emails" do
    let(:president) { Fabricate(:person) }
    let(:vorstand) { Fabricate(:group, type: Group::SektionVorstand.sti_name, parent: sektion) }
    let!(:president_role) do
      Fabricate(:role, person: president, group: vorstand,
        type: Group::SektionVorstand::Praesident.sti_name)
    end

    it "returns the sektion president email" do
      expect(reminder.president_emails).to eq([president.email])
    end

    it "excludes presidents without an email" do
      president.update!(email: nil)
      expect(reminder.president_emails).to be_empty
    end
  end

  describe "#any?" do
    context "without active Siegelimkers" do
      it { is_expected.not_to be_any }
    end

    context "with an active Siegelimker role" do
      let!(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion: sektion) }

      it { is_expected.to be_any }
    end

    context "with an expired Siegelimker role" do
      let!(:beekeeper_role) do
        Fabricate(:siegel_imker_role, sektion: sektion, end_on: 1.day.ago)
      end

      it { is_expected.not_to be_any }
    end
  end

  describe "#related_member_data" do
    let(:beekeeper) { Fabricate(:person, first_name: "Hans", last_name: "Imker") }
    let!(:beekeeper_role) { Fabricate(:siegel_imker_role, person: beekeeper, sektion: sektion) }

    it "returns an array" do
      expect(reminder.related_member_data).to be_an(Array)
    end

    it "contains the sektion name" do
      expect(reminder.related_member_data.first[0]).to eq(sektion.name)
    end

    it "contains last name" do
      expect(reminder.related_member_data.first[1]).to eq("Imker")
    end

    it "contains first name" do
      expect(reminder.related_member_data.first[2]).to eq("Hans")
    end

    context "with a qcontrol" do
      before {
        Fabricate(:qcontrol, person: beekeeper, group: sektion, control_date: Date.new(2024, 5, 1))
      }

      it "includes the formatted last inspection date" do
        expect(reminder.related_member_data.first[10]).to eq("01.05.2024")
      end
    end

    context "without qcontrols" do
      it "falls back to the epoch date" do
        epoch = Time.zone.at(0).to_date.strftime("%d.%m.%Y")
        expect(reminder.related_member_data.first[10]).to eq(epoch)
      end
    end

    context "sorted by last control date ascending (oldest first)" do
      let(:newer_beekeeper) { Fabricate(:person) }
      let!(:newer_beekeeper_role) {
        Fabricate(:siegel_imker_role, person: newer_beekeeper, sektion: sektion)
      }

      before do
        Fabricate(:qcontrol, person: beekeeper, group: sektion, control_date: 2.years.ago.to_date)
        Fabricate(:qcontrol, person: newer_beekeeper, group: sektion,
          control_date: 1.year.ago.to_date)
      end

      it "orders entries with oldest last inspection first" do
        dates = reminder.related_member_data.map { |row| Date.strptime(row[10], "%d.%m.%Y") }
        expect(dates).to eq(dates.sort)
      end
    end

    context "beekeepers with no qcontrol appear before those with one" do
      let(:inspected_beekeeper) { Fabricate(:person) }
      let!(:inspected_role) {
        Fabricate(:siegel_imker_role, person: inspected_beekeeper, sektion: sektion)
      }

      before {
        Fabricate(:qcontrol, person: inspected_beekeeper, group: sektion,
          control_date: 10.years.ago.to_date)
      }

      it "lists the uninspected beekeeper first" do
        names = reminder.related_member_data.pluck(1)
        expect(names.first).to eq(beekeeper.last_name)
      end
    end

    context "excludes beekeepers from a different sektion" do
      let(:other_sektion) { Fabricate(:sektion, parent: kantonalverband, name: "Andere Sektion") }
      let(:other_beekeeper) { Fabricate(:person) }
      let!(:other_role) {
        Fabricate(:siegel_imker_role, person: other_beekeeper, sektion: other_sektion)
      }

      it "does not include the other sektion's beekeepers" do
        expect(reminder.related_member_data.pluck(0)).not_to include(other_sektion.name)
      end
    end

    context "excludes beekeepers with an expired role" do
      let(:expired_beekeeper) { Fabricate(:person) }
      let!(:expired_role) do
        Fabricate(:siegel_imker_role, person: expired_beekeeper, sektion: sektion,
          end_on: 1.day.ago)
      end

      it "does not include the expired beekeeper" do
        names = reminder.related_member_data.pluck(1)
        expect(names).not_to include(expired_beekeeper.last_name)
      end
    end
  end

  describe "for a Kantonalverband" do
    subject(:reminder) { GroupInspectionReminder.new(kantonalverband, Person.none) }

    let!(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion: sektion) }

    describe "#any?" do
      it "finds Siegelimkers across all child Sektionen" do
        expect(reminder).to be_any
      end
    end

    describe "#related_member_data" do
      it "includes Siegelimkers from child Sektionen" do
        expect(reminder.related_member_data.length).to eq(1)
      end

      it "shows the Sektion name for each entry" do
        expect(reminder.related_member_data.first[0]).to eq(sektion.name)
      end
    end
  end
end
