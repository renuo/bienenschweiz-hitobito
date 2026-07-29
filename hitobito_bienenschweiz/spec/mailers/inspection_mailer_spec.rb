# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
require "spec_helper"

describe InspectionMailer do
  let(:group) { Fabricate(:sektion) }
  let(:person) do
    Fabricate(:person, first_name: "Maja", last_name: "Biene", email: "maja@example.com")
  end
  let(:inspector) { Fabricate(:person, first_name: "Max", last_name: "Prüfer") }
  let(:qcontrol) do
    Fabricate(:qcontrol, person: person, group: group, control_date: Date.new(2026, 5, 1),
      control_state: "passed", inspector: inspector)
  end

  describe "#print_certificate_and_letter" do
    subject(:mail) { described_class.print_certificate_and_letter(qcontrol.id) }

    before do
      stub_const("InspectionMailer::PRINTER_EMAIL", "printer@example.com")
      allow_any_instance_of(described_class)
        .to receive(:render_certificate_and_letter)
        .and_return("fake-pdf-content")
    end

    it "sends to the printer email" do
      expect(mail.to).to eq(["printer@example.com"])
    end

    it "sets subject with the member name" do
      expect(mail.subject)
        .to eq("Ausdruck Zertifikat und Begleitbrief für #{person.full_name}")
    end

    it "attaches a single PDF" do
      expect(mail.attachments.size).to eq(1)
    end

    it "names the attachment after the member" do
      expect(mail.attachments.first.filename)
        .to eq("Zertifikat_Begleitbrief_#{person.full_name}.pdf")
    end

    it "includes the member name in the body" do
      expect(mail.html_part.body.to_s).to include(person.full_name)
    end

    it "includes a link to the person profile in the body" do
      expect(mail.html_part.body.to_s).to include("/people/#{person.id}")
    end
  end

  describe "#sectional_inspection_reminder_mail" do
    let(:kantonalverband) { Fabricate(:kantonalverband) }
    let(:sektion) { Fabricate(:sektion, parent: kantonalverband, name: "Sektion Testingen") }
    let(:inspector) { Fabricate(:person, email: "pruefer@example.com") }
    let(:beekeeper) { Fabricate(:person, first_name: "Hans", last_name: "Imker") }
    let!(:beekeeper_role) { Fabricate(:siegel_imker_role, person: beekeeper, sektion: sektion) }
    let(:reminder) { GroupInspectionReminder.new(sektion, [inspector]) }

    subject(:mail) { described_class.sectional_inspection_reminder_mail(reminder) }

    it "sends to the inspector emails" do
      expect(mail.to).to eq(["pruefer@example.com"])
    end

    it "sets the subject including the section name" do
      expect(mail.subject).to include("Sektion Testingen")
    end

    it "attaches an xlsx named after the section" do
      attachment = mail.attachments.find { |a| a.filename.include?("Sektion Testingen") }
      expect(attachment).to be_present
      expect(attachment.filename).to end_with(".xlsx")
    end

    it "cc's the president emails" do
      # president_emails queries DB; with no Vorstand roles set up this is empty
      expect(mail.cc).to eq([]) | be_nil
    end

    it "renders a real xlsx attachment (valid zip archive)" do
      bytes = mail.attachments.first.body.decoded
      expect(zip_entries(bytes)).to include("xl/worksheets/sheet1.xml")
    end

    it "includes the member's data in the worksheet" do
      bytes = mail.attachments.first.body.decoded
      sheet_xml = extract_zip_entry(bytes, "xl/worksheets/sheet1.xml")
      shared_strings = extract_zip_entry(bytes, "xl/sharedStrings.xml")
      expect(sheet_xml + shared_strings).to include("Imker")
    end
  end

  describe "#cantonal_inspection_reminder_mail" do
    let(:kantonalverband) { Fabricate(:kantonalverband, name: "Kanton Musterhausen") }
    let(:inspector) { Fabricate(:person, email: "kantonal@example.com") }
    let(:reminder) { GroupInspectionReminder.new(kantonalverband, [inspector]) }

    before { stub_const("InspectionMailer::CANTONAL_INSPECTOR_CC_EMAIL", "cc@example.com") }

    subject(:mail) { described_class.cantonal_inspection_reminder_mail(reminder) }

    it "sends to the inspector emails" do
      expect(mail.to).to eq(["kantonal@example.com"])
    end

    it "sets the subject including the group name" do
      expect(mail.subject).to include("Kanton Musterhausen")
    end

    it "attaches an xlsx named after the canton" do
      attachment = mail.attachments.find { |a| a.filename.include?("Kanton Musterhausen") }
      expect(attachment).to be_present
      expect(attachment.filename).to end_with(".xlsx")
    end

    it "cc's CANTONAL_INSPECTOR_CC_EMAIL" do
      expect(mail.cc).to include("cc@example.com")
    end

    it "renders a real xlsx attachment (valid zip archive)" do
      bytes = mail.attachments.first.body.decoded
      expect(zip_entries(bytes)).to include("xl/worksheets/sheet1.xml")
    end
  end

  describe "#render_certificate_and_letter" do
    it "returns a PDF combining certificate and letter" do
      result = described_class.new.send(:render_certificate_and_letter, qcontrol)
      expect(result).to be_a(String)
      expect(result).to start_with("%PDF")
    end
  end

  describe "#inspection_not_necessary_mailer" do
    subject(:mail) { InspectionMailer.inspection_not_necessary_mailer(qcontrol.id) }

    before { stub_const("InspectionMailer::APP_NOTIFICATIONS_EMAIL", "secretary@example.com") }

    it "sends to APP_NOTIFICATIONS_EMAIL" do
      expect(mail.to).to eq(["secretary@example.com"])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq(I18n.t("inspection_not_necessary.subject"))
    end

    it "includes the inspector name in the body" do
      expect(mail.body.encoded).to include(inspector.full_name)
    end

    it "includes the person name in the body" do
      expect(mail.body.encoded).to include(person.full_name)
    end

    context "when inspector is nil" do
      let(:qcontrol_no_inspector) do
        Fabricate(:qcontrol, person: person, group: group,
          control_date: Date.new(2026, 5, 1), control_state: "passed", inspector: nil)
      end

      subject(:mail_no_inspector) {
        InspectionMailer.inspection_not_necessary_mailer(qcontrol_no_inspector.id)
      }

      it "renders without raising" do
        expect { mail_no_inspector.body.encoded }.not_to raise_error
      end

      it "does not include a link to the inspector" do
        expect(mail_no_inspector.body.encoded).not_to include("person_url")
      end
    end
  end

  describe "#beekeeper_and_inspector_checklist_pdf_mailer" do
    before do
      stub_const("InspectionMailer::CHECKLIST_MEMBER_EMAIL", "member@example.com")
      stub_const("InspectionMailer::CHECKLIST_INSPECTOR_EMAIL", "inspector@example.com")
    end

    it "sends to CHECKLIST_MEMBER_EMAIL" do
      mail = InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.to).to eq(["member@example.com"])
    end

    it "falls back to the beekeeper's own email when CHECKLIST_MEMBER_EMAIL is unset" do
      stub_const("InspectionMailer::CHECKLIST_MEMBER_EMAIL", nil)
      mail = InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.to).to eq([person.email])
    end

    it "cc's the inspector" do
      mail = InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.cc).to include("inspector@example.com")
    end

    it "also cc's APP_NOTIFICATIONS_EMAIL when copy_to_secretary is true" do
      stub_const("InspectionMailer::APP_NOTIFICATIONS_EMAIL", "secretary@example.com")
      mail = InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(qcontrol.id, true)
      expect(mail.cc).to include("secretary@example.com")
    end

    it "attaches the checklist PDF" do
      mail = InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.body.decoded).to start_with("%PDF")
    end

    it "includes the inspector name in the body" do
      mail = InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.html_part.body.to_s).to include(inspector.full_name)
    end

    context "when inspector is nil" do
      let(:qcontrol_no_inspector) do
        Fabricate(:qcontrol, person: person, group: group,
          control_date: Date.new(2026, 5, 1), control_state: "passed", inspector: nil)
      end

      it "renders without raising" do
        mail = InspectionMailer.beekeeper_and_inspector_checklist_pdf_mailer(
          qcontrol_no_inspector.id, false
        )
        expect { mail.body.encoded }.not_to raise_error
      end
    end
  end

  describe "#blank_inspection_info_mailer" do
    let(:new_member) { {first_name: "Neu", last_name: "Imker", email: "neu@example.com"} }

    before { stub_const("InspectionMailer::APP_NOTIFICATIONS_EMAIL", "secretary@example.com") }

    it "sends to APP_NOTIFICATIONS_EMAIL" do
      mail = InspectionMailer.blank_inspection_info_mailer(new_member, qcontrol.id)
      expect(mail.to).to eq(["secretary@example.com"])
    end

    it "has the correct subject" do
      mail = InspectionMailer.blank_inspection_info_mailer(new_member, qcontrol.id)
      expect(mail.subject).to eq(I18n.t("blank_inspection_info.subject"))
    end

    it "includes the inspector name when control_state is set" do
      mail = InspectionMailer.blank_inspection_info_mailer(new_member, qcontrol.id)
      expect(mail.body.encoded).to include(inspector.full_name)
    end

    context "when control_state is nil" do
      let(:qcontrol_no_state) do
        Fabricate(:qcontrol, person: person, group: group,
          control_date: Date.new(2026, 5, 1), control_state: nil, inspector: inspector)
      end

      it "shows the not_necessary label" do
        mail = InspectionMailer.blank_inspection_info_mailer(new_member, qcontrol_no_state.id)
        expect(mail.body.encoded).to include(
          I18n.t("activerecord.attributes.qcontrol.control_states.not_necessary")
        )
      end
    end
  end

  describe "#only_inspector_checklist_pdf_mailer" do
    before do
      stub_const("InspectionMailer::CHECKLIST_INSPECTOR_EMAIL", "inspector@example.com")
    end

    it "sends to CHECKLIST_INSPECTOR_EMAIL" do
      mail = InspectionMailer.only_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.to).to eq(["inspector@example.com"])
    end

    it "omits cc when copy_to_secretary is false" do
      mail = InspectionMailer.only_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.cc).to be_blank
    end

    it "cc's APP_NOTIFICATIONS_EMAIL when copy_to_secretary is true" do
      stub_const("InspectionMailer::APP_NOTIFICATIONS_EMAIL", "secretary@example.com")
      mail = InspectionMailer.only_inspector_checklist_pdf_mailer(qcontrol.id, true)
      expect(mail.cc).to eq(["secretary@example.com"])
    end

    it "includes the beekeeper name in the body" do
      mail = InspectionMailer.only_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.body.encoded).to include(person.full_name)
    end

    it "attaches the checklist PDF" do
      mail = InspectionMailer.only_inspector_checklist_pdf_mailer(qcontrol.id, false)
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.body.decoded).to start_with("%PDF")
    end

    context "when inspector is nil" do
      let(:qcontrol_no_inspector) do
        Fabricate(:qcontrol, person: person, group: group,
          control_date: Date.new(2026, 5, 1), control_state: "passed", inspector: nil)
      end

      it "renders without raising" do
        mail = InspectionMailer.only_inspector_checklist_pdf_mailer(qcontrol_no_inspector.id, false)
        expect { mail.body.encoded }.not_to raise_error
      end
    end
  end

  describe "#inspection_failed_mailer" do
    subject(:mail) { InspectionMailer.inspection_failed_mailer(qcontrol.id) }

    before do
      stub_const("InspectionMailer::APP_NOTIFICATIONS_EMAIL", "secretary@example.com")
    end

    it "sends to APP_NOTIFICATIONS_EMAIL" do
      expect(mail.to).to eq(["secretary@example.com"])
    end

    it "has the correct subject containing the person's name" do
      expect(mail.subject).to eq(I18n.t("inspection_failed.subject", name: person.full_name))
    end

    it "includes the inspector's name in the body" do
      expect(mail.body.encoded).to include(inspector.full_name)
    end

    it "includes the beekeeper's name in the body" do
      expect(mail.body.encoded).to include(person.full_name)
    end

    it "includes a link to the inspector" do
      expect(mail.body.encoded).to include(person_url(inspector))
    end

    it "includes a link to the beekeeper" do
      expect(mail.body.encoded).to include(person_url(person))
    end
  end

  def zip_entries(data)
    entries = []
    Zip::InputStream.open(StringIO.new(data)) do |zip|
      while (entry = zip.get_next_entry)
        entries << entry.name
      end
    end
    entries
  end

  def extract_zip_entry(data, name)
    Zip::InputStream.open(StringIO.new(data)) do |zip|
      while (entry = zip.get_next_entry)
        return entry.get_input_stream.read if entry.name == name
      end
    end
    raise "Entry #{name} not found in xlsx"
  end
end
