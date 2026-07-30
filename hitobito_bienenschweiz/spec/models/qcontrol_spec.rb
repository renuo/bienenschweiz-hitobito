# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Qcontrol do
  let(:group) { groups(:aarau_und_umgebung) }
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

  describe "#set_control_state" do
    let(:section) do
      Fabricate(:quality_control_section, number: 1, title: "Standort",
        version: QualityControlSection.version)
    end
    let(:question) do
      Fabricate(:quality_control_question, quality_control_section: section, number: 1,
        title: "Frage")
    end
    let(:qcontrol_without_state) do
      Fabricate(:qcontrol, person: person, group: group, control_date: Date.new(2026, 5, 1),
        control_state: nil)
    end

    context "when an answer is partially_passed (and none is not_passed)" do
      before do
        Fabricate(:quality_control_answer, qcontrol: qcontrol_without_state,
          quality_control_question: question, fulfilled: "partially_passed")
        qcontrol_without_state.save!
      end

      it "sets control_state to partially_passed" do
        expect(qcontrol_without_state.control_state).to eq("partially_passed")
      end
    end
  end

  describe "notify_beekeeper_and_inspector" do
    let(:person_without_email) { Fabricate(:person, email: nil) }
    let(:qcontrol) do
      Fabricate(:qcontrol, person: person_without_email, group: group,
        control_date: Date.new(2026, 5, 1), control_state: "passed")
    end

    it "calls only_inspector_checklist_pdf_mailer when person has no email" do
      mail_double = instance_double(ActionMailer::MessageDelivery, deliver_later: nil)
      expect(InspectionMailer).to receive(:only_inspector_checklist_pdf_mailer)
        .with(qcontrol.id, false)
        .and_return(mail_double)
      qcontrol.notify_beekeeper_and_inspector(false)
    end
  end

  describe "#as_full_mobile_json" do
    it "includes author when present" do
      author = Fabricate(:person)
      qcontrol = Fabricate(:qcontrol, person: person, group: group, author: author,
        control_date: Date.new(2026, 5, 1))
      json = qcontrol.as_full_mobile_json
      expect(json["author"]).to eq({
        "id" => author.id,
        "firstname" => author.first_name,
        "lastname" => author.last_name
      })
    end

    it "omits author key when author is nil" do
      qcontrol = Fabricate(:qcontrol, person: person, group: group, author: nil,
        control_date: Date.new(2026, 5, 1))
      json = qcontrol.as_full_mobile_json
      expect(json).not_to have_key("author")
    end
  end

  describe "fee creation" do
    let(:kader_group) { Fabricate(:group, parent: group, type: Group::Kader.sti_name) }
    let(:inspector) { Fabricate(:fachperson_produkte, group_id: kader_group.id) }
    let(:qcontrol) do
      Fabricate(:qcontrol, person: person, group: group, inspector: inspector,
        control_date: Date.new(2026, 5, 1), control_state: "passed")
    end

    describe "#should_create_fee?" do
      it "is true when all conditions are met" do
        expect(qcontrol.should_create_fee?).to be(true)
      end

      it "is false without a beekeeper" do
        qcontrol.person = nil
        expect(qcontrol.should_create_fee?).to be(false)
      end

      it "is false without an inspector" do
        qcontrol.inspector = nil
        expect(qcontrol.should_create_fee?).to be(false)
      end

      it "is false when a fee has already been created" do
        qcontrol.fee_creation_state = "fee_ok"
        expect(qcontrol.should_create_fee?).to be(false)
      end

      it "is false when no fee is required" do
        qcontrol.fee_creation_state = "fee_not_required"
        expect(qcontrol.should_create_fee?).to be(false)
      end

      it "is false when the group is not a Sektion" do
        qcontrol.group = groups(:aargauer_kantonalverband)
        expect(qcontrol.should_create_fee?).to be(false)
      end

      it "is false when no control was performed" do
        qcontrol.no_control_reason = "beekeeper_deceased"
        expect(qcontrol.should_create_fee?).to be(false)
      end
    end

    describe "#create_fee" do
      let(:service) do
        instance_double(Kas::FeeCreationService, perform: nil, ok?: true,
          generated_fee: {id: 42, total_amount: "20.00", code: "qcontrol"})
      end

      before do
        allow(Kas::FeeCreationService).to receive(:new).with(qcontrol).and_return(service)
      end

      it "calls perform on the fee creation service" do
        qcontrol.create_fee
        expect(service).to have_received(:perform)
      end

      it "sets fee_creation_state to fee_ok" do
        expect { qcontrol.create_fee }.to change { qcontrol.reload.fee_creation_state }
          .from("fee_not_created").to("fee_ok")
      end

      it "stores the fee_id, fee_total_amount and fee_type_code" do
        qcontrol.create_fee
        qcontrol.reload
        expect(qcontrol.fee_id).to eq(42)
        expect(qcontrol.fee_total_amount).to eq(20)
        expect(qcontrol.fee_type_code).to eq("qcontrol")
      end

      context "when the service does not succeed" do
        let(:service) do
          instance_double(Kas::FeeCreationService, perform: nil, ok?: false, generated_fee: {})
        end

        it "does not change fee_creation_state" do
          expect { qcontrol.create_fee }.not_to change { qcontrol.reload.fee_creation_state }
        end

        it "does not set fee_id, fee_total_amount or fee_type_code" do
          qcontrol.create_fee
          qcontrol.reload
          expect(qcontrol.fee_id).to be_nil
          expect(qcontrol.fee_total_amount).to be_nil
          expect(qcontrol.fee_type_code).to be_nil
        end
      end
    end
  end

  describe "#beekeeper_role" do
    it "returns nil when person is nil" do
      orphan = Fabricate(:qcontrol, person: nil, group: group,
        control_date: Date.new(2026, 5, 1))
      expect(orphan.send(:beekeeper_role)).to be_nil
    end
  end

  describe "notify_on_update" do
    let(:person) { Fabricate(:person) }
    let(:qcontrol) do
      Fabricate(:qcontrol, person: person, group: group, from_app: true, member_notified: false,
        control_date: Date.new(2026, 5, 1), control_state: "passed")
    end

    it "sends notification when all conditions met on update" do
      expect do
        qcontrol.notify_on_update
      end.to have_enqueued_mail.at_least(:once)
    end

    it "calls notify_beekeeper_and_inspector_and_secretary when notify_beekeeper_and_inspector?" do
      allow(qcontrol).to receive(:notify_beekeeper_and_inspector?).and_return(true)
      allow(qcontrol).to receive(:print_certificate_and_letter?).and_return(false)
      expect(qcontrol).to receive(:notify_beekeeper_and_inspector_and_secretary)
      qcontrol.notify_on_update
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
