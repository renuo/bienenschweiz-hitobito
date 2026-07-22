# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe Export::Tabular::FeedbackRounds::Result do
  let(:event) { Fabricate(:course, kind: Fabricate(:event_kind)) }
  let(:round) { Fabricate(:feedback_round, event:) }
  let(:rating_question) { Fabricate(:feedback_question, kind: "rating", text: "Wie war der Kurs?") }
  let(:yes_no_question) { Fabricate(:feedback_question, kind: "yes_no", text: "Weiterempfehlung?") }

  let(:participant) { Fabricate(:person, first_name: "Bea", last_name: "Imker") }
  let!(:invitation) do
    participation = Fabricate(:event_participation, event:, active: true, participant:)
    Fabricate(:feedback_invitation, feedback_round: round, participation:)
  end

  before do
    Fabricate(:feedback_answer, feedback_invitation: invitation, feedback_question: rating_question,
      rating: 4)
    Fabricate(:feedback_answer, feedback_invitation: invitation, feedback_question: yes_no_question,
      rating: nil, yes_no: true)
  end

  subject(:exporter) { described_class.new(round) }

  it "has a column for person, submitted_at and each question in the catalog" do
    expect(exporter.attribute_labels).to include(
      person: "Person",
      submitted_at: "Eingereicht am",
      "question_#{rating_question.id}": rating_question.text,
      "question_#{yes_no_question.id}": yes_no_question.text
    )
  end

  it "has one row per invited participant" do
    expect(exporter.data_rows.to_a.size).to eq(1)
  end

  it "exports the participant's name in the person column" do
    row = Export::Tabular::FeedbackRounds::ResultRow.new(invitation)
    expect(row.fetch(:person)).to include("Bea Imker")
  end

  it "exports each answer's value in its question's column" do
    row = Export::Tabular::FeedbackRounds::ResultRow.new(invitation)
    expect(row.fetch(:"question_#{rating_question.id}")).to eq(4)
    expect(row.fetch(:"question_#{yes_no_question.id}")).to eq(I18n.t("global.yes"))
  end

  it "leaves unanswered questions blank" do
    other_question = Fabricate(:feedback_question, kind: "text")
    row = Export::Tabular::FeedbackRounds::ResultRow.new(invitation)
    expect(row.fetch(:"question_#{other_question.id}")).to be_nil
  end

  describe "submitted_at" do
    let(:submitted_at) { Time.zone.local(2026, 7, 22, 14, 30) }

    before { invitation.update!(submitted_at:) }

    it "keeps the full timestamp for xlsx (styled as datetime, not date-only)" do
      row = Export::Tabular::FeedbackRounds::ResultRow.new(invitation, :xlsx)
      expect(row.fetch(:submitted_at)).to eq(submitted_at)
    end

    it "formats as a localized date and time for csv" do
      row = Export::Tabular::FeedbackRounds::ResultRow.new(invitation, :csv)
      expect(row.fetch(:submitted_at)).to eq("22.07.2026 14:30")
    end

    it "styles the submitted_at column as a datetime in xlsx" do
      index = exporter.attributes.index(:submitted_at)
      expect(exporter.attribute_styles[index]).to eq(:datetime)
    end
  end
end
