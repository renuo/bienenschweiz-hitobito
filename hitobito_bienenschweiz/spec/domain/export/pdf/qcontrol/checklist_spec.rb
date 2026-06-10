# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Export::Pdf::Qcontrol::Checklist do
  let(:group) { Fabricate(:sektion, code: 1234) }
  let(:person) do
    Fabricate(:person, first_name: "Maja", last_name: "Biene", street: "Blumenweg",
      housenumber: "5", zip_code: "8000", town: "Zürich", email: "maja@example.com")
  end
  let(:inspector) { Fabricate(:person, first_name: "Ida", last_name: "Inspektorin") }
  let(:qcontrol) do
    Fabricate(:qcontrol, person: person, group: group, inspector: inspector,
      control_date: Date.new(2026, 5, 1), control_state: "passed")
  end

  let(:section) do
    Fabricate(:quality_control_section, number: 1, title: "Standort",
      version: QualityControlSection.version)
  end
  let(:question_one) do
    Fabricate(:quality_control_question, quality_control_section: section, number: 1,
      title: "Frage eins", description: 'Zeile1\nZeile2')
  end
  let(:question_two) do
    Fabricate(:quality_control_question, quality_control_section: section, number: 2,
      title: "Frage zwei", description: nil)
  end

  subject(:text) { PDF::Inspector::Text.analyze(described_class.new(qcontrol).render).strings }

  before do
    person.phone_numbers.create!(number: "+41 79 123 45 67", label: "Mobil")
    Fabricate(:quality_control_answer, qcontrol: qcontrol, quality_control_question: question_one,
      fulfilled: "passed", notes: "Alles gut", deadline_at: nil)
    Fabricate(:quality_control_answer, qcontrol: qcontrol, quality_control_question: question_two,
      fulfilled: "partially_passed", notes: "Nachbessern", deadline_at: Date.new(2026, 7, 1))
  end

  it "renders title and header" do
    expect(text).to include("Checkliste für die Betriebsprüfung")
    expect(text).to include("für das Honig-Qualitätssiegel-Programm apisuisse")
  end

  it "renders control info" do
    expect(text).to include("01.05.2026")
    expect(text).to include("1234")
  end

  it "renders beekeeper data" do
    expect(text).to include("Maja")
    expect(text).to include("Biene")
    expect(text).to include("Blumenweg 5")
    expect(text).to include("8000 Zürich")
    expect(text).to include("maja@example.com")
    expect(text).to include("+41 79 123 45 67")
  end

  it "renders inspector data" do
    expect(text).to include("Ida")
    expect(text).to include("Inspektorin")
  end

  it "renders the questions table" do
    expect(text).to include("Standort")
    expect(text).to include("1.1")
    expect(text).to include("Frage eins")
    expect(text).to include("Zeile1")
    expect(text).to include("Zeile2")
    expect(text).to include("1.2")
    expect(text).to include("Frage zwei")
    expect(text).to include("Alles gut")
    expect(text).to include("Nachbessern")
    expect(text).to include("01.07.2026")
    expect(text.count("×")).to eq(2)
  end

  it "renders the page footer" do
    # the footer is drawn with a repeater (form xobject),
    # which PDF::Inspector does not extract
    page_text = PDF::Reader.new(StringIO.new(described_class.new(qcontrol).render)).pages.first.text
    expect(page_text).to include("Checkliste für die Betriebskontrolle")
    expect(page_text).to include("Honigkommission apisuisse #{Time.zone.today.year}")
  end

  context "without answers" do
    before { qcontrol.quality_control_answers.destroy_all }

    it "renders no questions table" do
      expect(text).not_to include("Prüfkriterium")
    end
  end

  context "with a previous qcontrol" do
    before do
      Fabricate(:qcontrol, person: person, group: group, inspector: inspector,
        control_date: Date.new(2024, 4, 1), control_state: "passed")
    end

    it "renders the previous control date next to the periodic control checkbox" do
      expect(text.join(" ")).to include("Datum der letzten Kontrolle: 01.04.2024")
    end
  end

  context "with an orphan qcontrol" do
    let(:qcontrol) do
      Fabricate(:qcontrol, person: nil, group: group, inspector: nil,
        control_date: Date.new(2026, 5, 1), control_state: "passed")
    end

    before { qcontrol.quality_control_answers.destroy_all }

    it "renders without raising" do
      expect(text).to include("Checkliste für die Betriebsprüfung")
    end
  end

  describe ".filename" do
    it "includes person name and control date" do
      expect(described_class.filename(qcontrol))
        .to eq("checkliste_betriebspruefung-maja_biene-2026-05-01.pdf")
    end

    it "is nil-safe for orphan qcontrols" do
      qcontrol.person = nil
      qcontrol.control_date = nil
      expect(described_class.filename(qcontrol)).to eq("checkliste_betriebspruefung.pdf")
    end
  end
end
