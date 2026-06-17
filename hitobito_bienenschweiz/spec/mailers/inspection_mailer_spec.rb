# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe InspectionMailer do
  let(:group) { Fabricate(:sektion) }
  let(:person) do
    Fabricate(:person, first_name: "Maja", last_name: "Biene", email: "maja@example.com")
  end
  let(:qcontrol) do
    Fabricate(:qcontrol, person: person, group: group, control_date: Date.new(2026, 5, 1),
      control_state: "passed")
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
end
