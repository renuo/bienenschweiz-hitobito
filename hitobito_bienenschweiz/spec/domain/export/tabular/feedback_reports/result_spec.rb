# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Export::Tabular::FeedbackReports::Result do
  # Distinct kind/group per course so their computed Event::Course#number differs,
  # letting us assert the course_number column tracks the right course per row.
  let(:kind_a) { Fabricate(:event_kind, abbreviation: "KA") }
  let(:kind_b) { Fabricate(:event_kind, abbreviation: "KB") }
  let(:course_a) {
    Fabricate(:course, name: "Kurs A", kind: kind_a, groups: [groups(:aarau_und_umgebung)])
  }
  let(:course_b) {
    Fabricate(:course, name: "Kurs B", kind: kind_b, groups: [groups(:aargauisches_seetal)])
  }
  let(:round_a) { Fabricate(:feedback_round, event: course_a, kind: "final") }
  let(:round_b) { Fabricate(:feedback_round, event: course_b, kind: "final") }
  let(:rating_question) { Fabricate(:feedback_question, kind: "rating", text: "Wie war der Kurs?") }

  let(:participant_a) { Fabricate(:person, first_name: "Bea", last_name: "Imker") }
  let(:participant_b) { Fabricate(:person, first_name: "Carl", last_name: "Waber") }

  let!(:invitation_a) do
    participation = Fabricate(:event_participation, event: course_a, active: true,
      participant: participant_a)
    Fabricate(:feedback_invitation, feedback_round: round_a, participation:)
  end
  let!(:invitation_b) do
    participation = Fabricate(:event_participation, event: course_b, active: true,
      participant: participant_b)
    Fabricate(:feedback_invitation, feedback_round: round_b, participation:)
  end

  before do
    Fabricate(:feedback_answer, feedback_invitation: invitation_a,
      feedback_question: rating_question, rating: 5)
    Fabricate(:feedback_answer, feedback_invitation: invitation_b,
      feedback_question: rating_question, rating: 2)
  end

  subject(:exporter) { described_class.new(FeedbackRound.where(id: [round_a.id, round_b.id])) }

  it "has a column for course number, person, submitted_at and each question" do
    expect(exporter.attribute_labels).to include(
      course_number: "Kursnummer",
      person: "Person",
      submitted_at: "Eingereicht am",
      "question_#{rating_question.id}": rating_question.text
    )
  end

  it "has one row per invited participant, across all given rounds" do
    expect(exporter.data_rows.to_a.size).to eq(2)
  end

  it "exports each row's course number, matching its own course" do
    row_a = Export::Tabular::FeedbackReports::ResultRow.new(invitation_a)
    row_b = Export::Tabular::FeedbackReports::ResultRow.new(invitation_b)

    expect(row_a.fetch(:course_number)).to eq(course_a.reload.number)
    expect(row_b.fetch(:course_number)).to eq(course_b.reload.number)
    expect(row_a.fetch(:course_number)).not_to eq(row_b.fetch(:course_number))
  end

  it "still exports the participant's name and answers, like the single-round export" do
    row = Export::Tabular::FeedbackReports::ResultRow.new(invitation_a)

    expect(row.fetch(:person)).to include("Bea Imker")
    expect(row.fetch(:"question_#{rating_question.id}")).to eq(5)
  end
end
