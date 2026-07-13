# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe InspectionService do
  subject(:service) { InspectionService.new }

  let(:kantonalverband) { Fabricate(:kantonalverband) }
  let(:sektion) { Fabricate(:sektion, parent: kantonalverband) }
  let(:mail_double) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  describe "#build_structure_mails" do
    context "when the group has no active Siegelimkers" do
      it "returns an empty array" do
        expect(service.build_structure_mails([sektion],
          :sectional_inspection_reminder_mail)).to be_empty
      end
    end

    context "when the group has active Siegelimkers" do
      let!(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion: sektion) }

      before do
        allow(InspectionMailer).to receive(:sectional_inspection_reminder_mail)
          .and_return(mail_double)
      end

      it "returns one result per group with Siegelimkers" do
        result = service.build_structure_mails([sektion],
          :sectional_inspection_reminder_mail)
        expect(result.length).to eq(1)
      end

      it "includes a GroupInspectionReminder for the group" do
        result = service.build_structure_mails([sektion],
          :sectional_inspection_reminder_mail)
        expect(result.first.reminder).to be_a(GroupInspectionReminder)
        expect(result.first.reminder.group).to eq(sektion)
      end

      it "includes the mail returned by the mailer" do
        result = service.build_structure_mails([sektion],
          :sectional_inspection_reminder_mail)
        expect(result.first.mail).to eq(mail_double)
      end

      it "calls the specified mailer method" do
        expect(InspectionMailer).to receive(:sectional_inspection_reminder_mail)
          .with(instance_of(GroupInspectionReminder)).and_return(mail_double)
        service.build_structure_mails([sektion], :sectional_inspection_reminder_mail)
      end
    end

    context "with multiple groups where only some have Siegelimkers" do
      let(:sektion_without_beekeepers) { Fabricate(:sektion, parent: kantonalverband) }
      let!(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion: sektion) }

      before do
        allow(InspectionMailer).to receive(:sectional_inspection_reminder_mail)
          .and_return(mail_double)
      end

      it "only includes groups that have active Siegelimkers" do
        result = service.build_structure_mails(
          [sektion, sektion_without_beekeepers], :sectional_inspection_reminder_mail
        )
        expect(result.length).to eq(1)
        expect(result.first.reminder.group).to eq(sektion)
      end
    end
  end

  describe "#deliver_inspection_reminders" do
    before do
      allow(InspectionMailer).to receive(:sectional_inspection_reminder_mail)
        .and_return(mail_double)
      allow(InspectionMailer).to receive(:cantonal_inspection_reminder_mail)
        .and_return(mail_double)
    end

    context "when there are groups with active Siegelimkers" do
      let!(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion: sektion) }

      it "calls deliver_now on each mail" do
        expect(mail_double).to receive(:deliver_now).at_least(:once)
        service.deliver_inspection_reminders
      end

      it "re-raises delivery errors when Sentry is not defined" do
        allow(mail_double).to receive(:deliver_now).and_raise(StandardError, "network error")
        hide_const("Sentry") if defined?(Sentry)
        expect {
          service.deliver_inspection_reminders
        }.to raise_error(StandardError, "network error")
      end

      it "reports delivery errors to Sentry when Sentry is defined" do
        error = StandardError.new("network error")
        allow(mail_double).to receive(:deliver_now).and_raise(error)
        sentry = double("Sentry")
        stub_const("Sentry", sentry)
        allow(sentry).to receive(:capture_exception)
        service.deliver_inspection_reminders
        expect(sentry).to have_received(:capture_exception).with(error, extra: {failed_index: 0})
      end
    end

    context "when no groups have active Siegelimkers" do
      it "delivers no mails" do
        expect(mail_double).not_to receive(:deliver_now)
        service.deliver_inspection_reminders
      end
    end
  end

  describe "#build_structure_mails with unsupported group type" do
    it "returns no mails for a Dachverband group (else branch in inspectors_for)" do
      dachverband = Group::Dachverband.first
      result = service.build_structure_mails([dachverband], :sectional_inspection_reminder_mail)
      expect(result).to be_empty
    end
  end

  describe "#retry_failed_inspection_reminder" do
    let!(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion: sektion) }

    before do
      allow(InspectionMailer).to receive(:cantonal_inspection_reminder_mail)
        .and_return(mail_double)
      allow(InspectionMailer).to receive(:sectional_inspection_reminder_mail)
        .and_return(mail_double)
    end

    it "delivers exactly one mail at the specified index" do
      expect(mail_double).to receive(:deliver_now).exactly(:once)
      service.retry_failed_inspection_reminder(0)
    end

    it "delivers only one mail even when multiple mails exist in the full list" do
      # Beekeepers in one sektion (under one kantonalverband) produce at least 2 mails
      # (one cantonal + one sectional), but retry delivers only the one at index 0
      delivery_count = 0
      allow(mail_double).to receive(:deliver_now) { delivery_count += 1 }
      service.retry_failed_inspection_reminder(0)
      expect(delivery_count).to eq(1)
    end
  end

  describe "inspector assignment" do
    context "for a Sektion" do
      let(:kader_group) { Fabricate(:group, type: Group::Kader.sti_name, parent: sektion) }
      let(:inspector) { Fabricate(:person) }
      let!(:inspector_role) do
        Fabricate(:role, person: inspector, group: kader_group,
          type: Group::Kader::FachpersonProdukte.sti_name)
      end
      let!(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion: sektion) }

      before do
        allow(InspectionMailer).to receive(:sectional_inspection_reminder_mail)
          .and_return(mail_double)
      end

      it "uses FachpersonProdukte from the Kader group as inspectors" do
        result = service.build_structure_mails([sektion],
          :sectional_inspection_reminder_mail)
        expect(result.first.reminder.inspector_emails).to include(inspector.email)
      end

      it "does not assign inactive inspectors" do
        inspector_role.update!(end_on: 1.day.ago)
        result = service.build_structure_mails([sektion],
          :sectional_inspection_reminder_mail)
        expect(result.first.reminder.inspector_emails).not_to include(inspector.email)
      end
    end

    context "for a Kantonalverband" do
      let(:vorstand_group) do
        Fabricate(:group, type: Group::KantonalverbandVorstand.sti_name, parent: kantonalverband)
      end
      let(:produkte_person) { Fabricate(:person) }
      let!(:produkte_role) do
        Fabricate(:role, person: produkte_person, group: vorstand_group,
          type: Group::KantonalverbandVorstand::Produkte.sti_name)
      end
      let!(:beekeeper_role) { Fabricate(:siegel_imker_role, sektion: sektion) }

      before do
        allow(InspectionMailer).to receive(:cantonal_inspection_reminder_mail)
          .and_return(mail_double)
      end

      it "uses KantonalverbandVorstand::Produkte as inspectors" do
        result = service.build_structure_mails([kantonalverband],
          :cantonal_inspection_reminder_mail)
        expect(result.first.reminder.inspector_emails).to include(produkte_person.email)
      end

      it "does not assign inactive inspectors" do
        produkte_role.update!(end_on: 1.day.ago)
        result = service.build_structure_mails([kantonalverband],
          :cantonal_inspection_reminder_mail)
        expect(result.first.reminder.inspector_emails).not_to include(produkte_person.email)
      end
    end
  end
end
