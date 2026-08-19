# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Export::Pdf::Qcontrol::CertificateLetter do
  let(:group) { groups(:aarau_und_umgebung) }
  let(:person) do
    Fabricate(:person, first_name: "Maja", last_name: "Biene",
      salutation: "Frau",
      street: "Blumenweg", housenumber: "5",
      zip_code: "8000", town: "Zürich")
  end
  let(:inspector) {
    Fabricate(:fachperson_produkte,
      group_id: groups(:kader_380).id,
      first_name: "Ida",
      last_name: "Inspektorin")
  }
  let(:qcontrol) do
    Fabricate(:qcontrol, person: person, group: group, inspector: inspector,
      control_date: Date.new(2026, 5, 1), control_state: "passed")
  end

  subject(:letter) { described_class.new(qcontrol) }

  describe "#render" do
    it "returns a non-empty PDF byte string" do
      result = letter.render
      expect(result).to be_a(String)
      expect(result).to start_with("%PDF")
    end

    it "includes the person's name in the rendered text" do
      text = PDF::Inspector::Text.analyze(letter.render).strings
      expect(text).to include("Maja Biene")
    end

    it "includes the person's address" do
      text = PDF::Inspector::Text.analyze(letter.render).strings
      expect(text.join(" ")).to include("Blumenweg")
    end

    it "includes the control date" do
      text = PDF::Inspector::Text.analyze(letter.render).strings
      expect(text.join(" ")).to include("2026")
    end

    context "when control_date is nil" do
      before { qcontrol.update_columns(control_date: nil) }

      it "renders an empty date string without raising" do
        expect(letter.render).to start_with("%PDF")
      end
    end
  end

  describe "salutation" do
    # the address block is the first thing written on the page
    def address_lines
      PDF::Inspector::Text.analyze(letter.render).strings.first(4)
    end

    it "prints the salutation as the first address line" do
      expect(address_lines).to eq(["Frau", "Maja Biene", "Blumenweg 5", "8000 Zürich"])
    end

    context "with a longer salutation" do
      before { person.update!(salutation: "Sehr geehrte Frau Doktor") }

      it "prints it as given" do
        expect(address_lines.first).to eq("Sehr geehrte Frau Doktor")
      end
    end

    context "without a salutation" do
      before { person.update!(salutation: nil) }

      it "omits the line and starts the address with the name" do
        expect(address_lines).to eq(["Maja Biene", "Blumenweg 5", "8000 Zürich",
          "Appenzell, im Mai 2026"])
      end
    end

    context "for a person with gender divers" do
      before { person.update!(gender: "d", salutation: "Guten Tag") }

      it "prints the salutation as given" do
        expect(address_lines).to eq(["Guten Tag", "Maja Biene", "Blumenweg 5", "8000 Zürich"])
      end
    end

    context "with a blank salutation" do
      before { person.update!(salutation: "") }

      it "omits the line" do
        expect(address_lines.first).to eq("Maja Biene")
      end
    end
  end

  describe "#draw_all" do
    it "does not raise" do
      expect { letter.draw_all }.not_to raise_error
    end
  end

  describe "with nil person (orphan qcontrol)" do
    let(:orphan_qcontrol) do
      Fabricate(:qcontrol, person: nil, group: group, inspector: inspector,
        control_date: Date.new(2026, 5, 1), control_state: "passed")
    end

    subject(:orphan_letter) { described_class.new(orphan_qcontrol) }

    it "renders without raising" do
      expect { orphan_letter.render }.not_to raise_error
    end

    it "returns a valid PDF" do
      expect(orphan_letter.render).to start_with("%PDF")
    end
  end

  describe "#draw_signatures" do
    it "embeds an additional image when a signature has an attached compatible image" do
      baseline = PDF::Inspector::XObject.analyze(described_class.new(qcontrol).render)
        .xobject_streams.length

      signatures(:certificate_letter_1).image.attach(
        io: Rails.root.join("spec", "fixtures", "files", "logo-icon.png").open,
        filename: "signature.png", content_type: "image/png"
      )

      with_image = PDF::Inspector::XObject.analyze(described_class.new(qcontrol).render)
        .xobject_streams.length
      expect(with_image).to eq(baseline + 1)
    end

    context "when a signature is missing" do
      before { signatures(:certificate_letter_2).destroy }

      it "renders without raising" do
        expect { letter.render }.not_to raise_error
      end

      it "does not render the missing signature's name" do
        text = PDF::Inspector::Text.analyze(letter.render).strings
        expect(text.join(" ")).not_to include("Markus Michel")
      end
    end
  end

  describe ".filename" do
    it "includes the person name and date" do
      expect(described_class.filename(qcontrol))
        .to eq("zertifikatsbrief-maja_biene-2026-05-01.pdf")
    end

    it "is nil-safe for orphan qcontrols" do
      qcontrol.person = nil
      qcontrol.control_date = nil
      expect(described_class.filename(qcontrol)).to eq("zertifikatsbrief.pdf")
    end
  end
end
