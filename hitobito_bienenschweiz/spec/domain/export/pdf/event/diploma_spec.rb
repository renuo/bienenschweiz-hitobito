# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Export::Pdf::Event::Diploma do
  let(:group) { Fabricate(:kantonalverband, name: "Kanton Bern") }
  let(:kind) { Fabricate(:event_kind, label: "Grundkurs") }
  let(:course) do
    Fabricate(:course, groups: [group], name: "Grundkurs 2026", kind: kind,
      diploma_location: "Bern", diploma_issued_at: Date.new(2026, 6, 20))
  end
  let(:participant_person) do
    Fabricate(:person, first_name: "Anna", last_name: "Imkerin", zip_code: "3000", town: "Bern")
  end
  let(:leader_person) do
    Fabricate(:person, first_name: "Kurt", last_name: "Kursleiter")
  end

  before do
    participant = Fabricate(:event_participation, event: course, participant: participant_person,
      active: true, qualified: true)
    Fabricate(:"Event::Course::Role::Participant", participation: participant)

    leader = Fabricate(:event_participation, event: course, participant: leader_person,
      active: true)
    Fabricate(:"Event::Role::Leader", participation: leader)
  end

  subject(:text) { PDF::Inspector::Text.analyze(described_class.new(course).render).strings }

  it "renders the participant name" do
    expect(text.join(" ")).to include("Anna Imkerin")
  end

  it "renders the participant city" do
    expect(text.join(" ")).to include("3000 Bern")
  end

  it "renders the course name and section name" do
    expect(text.join(" ")).to include("Grundkurs")
    expect(text.join(" ")).to include("Kanton Bern")
  end

  it "renders the congratulations text" do
    expect(text.join(" ")).to include("Herzliche Gratulation")
  end

  it "renders diploma_issued_at" do
    expect(text.join(" ")).to include("Juni 2026")
    expect(text.join(" ")).to include("20")
  end

  it "renders diploma_location" do
    expect(text.join(" ")).to include("Bern,")
  end

  it "renders the event leader as Kursleiter" do
    expect(text.join(" ")).to include("Kurt Kursleiter")
    expect(text).to include("Kursleiter")
  end

  it "renders the fixed official Markus Michel as Leiter Ressort Bildung" do
    expect(text.join(" ")).to include("Markus Michel")
    expect(text).to include("Leiter Ressort Bildung")
  end

  context "with multiple qualified participants" do
    let(:second_person) do
      Fabricate(:person, first_name: "Hans", last_name: "Müller",
        zip_code: "8000", town: "Zürich")
    end

    before do
      participation = Fabricate(:event_participation, event: course, participant: second_person,
        active: true, qualified: true)
      Fabricate(:"Event::Course::Role::Participant", participation: participation)
    end

    it "generates one page per qualified participant" do
      pages = PDF::Reader.new(StringIO.new(described_class.new(course).render)).pages
      expect(pages.length).to eq(2)
    end

    it "includes both participant names" do
      expect(text.join(" ")).to include("Anna Imkerin")
      expect(text.join(" ")).to include("Hans Müller")
    end
  end

  context "with a non-qualified participant" do
    let(:unqualified_person) { Fabricate(:person, first_name: "Franz", last_name: "Nope") }

    before do
      participation = Fabricate(:event_participation, event: course,
        participant: unqualified_person, active: true, qualified: false)
      Fabricate(:"Event::Course::Role::Participant", participation: participation)
    end

    it "does not print a page for the non-qualified participant" do
      pages = PDF::Reader.new(StringIO.new(described_class.new(course).render)).pages
      expect(pages.length).to eq(1)
      expect(text.join(" ")).not_to include("Franz Nope")
    end
  end

  context "with an AssistantLeader participant" do
    let(:assistant) { Fabricate(:person, first_name: "Maria", last_name: "Hilfsleiter") }

    before do
      p = Fabricate(:event_participation, event: course, participant: assistant, active: true)
      Fabricate(:"Event::Role::AssistantLeader", participation: p)
    end

    context "when diploma_only_leader is false (default)" do
      it "includes the assistant leader" do
        expect(text.join(" ")).to include("Maria Hilfsleiter")
      end
    end

    context "when diploma_only_leader is true" do
      let(:course) do
        Fabricate(:course, groups: [group], name: "Grundkurs 2026", kind: kind,
          diploma_location: "Bern", diploma_issued_at: Date.new(2026, 6, 20),
          diploma_only_leader: true)
      end

      it "excludes the assistant leader" do
        expect(text.join(" ")).not_to include("Maria Hilfsleiter")
      end

      it "still includes the Leader" do
        expect(text.join(" ")).to include("Kurt Kursleiter")
      end
    end
  end

  context "with three or more leaders" do
    let(:leader2) { Fabricate(:person, first_name: "Maria", last_name: "Zweit") }
    let(:leader3) { Fabricate(:person, first_name: "Peter", last_name: "Dritt") }

    before do
      [leader2, leader3].each do |person|
        p = Fabricate(:event_participation, event: course, participant: person, active: true)
        Fabricate(:"Event::Role::AssistantLeader", participation: p)
      end
    end

    it "renders all dynamic leader names" do
      expect(text.join(" ")).to include("Kurt Kursleiter")
      expect(text.join(" ")).to include("Maria Zweit")
      expect(text.join(" ")).to include("Peter Dritt")
    end

    it "always renders the fixed official" do
      expect(text.join(" ")).to include("Markus Michel")
    end
  end

  describe ".filename" do
    it "includes the event name" do
      expect(described_class.filename(course)).to eq("diplome_grundkurs_2026.pdf")
    end
  end
end
