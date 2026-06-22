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
end
