# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe Feedback::Report do
  let(:course) { Fabricate(:course, kind: Fabricate(:event_kind)) }
  let(:round) { Fabricate(:feedback_round, event: course, kind: "final") }

  let(:rating_question) { Fabricate(:feedback_question, kind: "rating", position: 1) }
  let(:yes_no_question) { Fabricate(:feedback_question, kind: "yes_no", position: 2) }
  let(:text_question) { Fabricate(:feedback_question, kind: "text", position: 3) }

  def submitted_invitation(round)
    invitation = Fabricate(:feedback_invitation, feedback_round: round)
    invitation.update!(submitted_at: Time.zone.now)
    invitation
  end

  subject(:report) { described_class.new(FeedbackRound.where(id: round.id)) }

  describe "#courses" do
    it "returns the distinct courses backing the given rounds" do
      expect(report.courses).to eq([course])
    end
  end

  describe "#invitation_count and #response_count" do
    it "counts all invitations but only submitted ones as responses" do
      submitted_invitation(round)
      Fabricate(:feedback_invitation, feedback_round: round) # not submitted

      expect(report.invitation_count).to eq(2)
      expect(report.response_count).to eq(1)
    end
  end

  describe "#rating_counts" do
    it "tallies rating answers into a 1..5 histogram, filling zero for missing values" do
      Fabricate(:feedback_answer, feedback_question: rating_question,
        feedback_invitation: submitted_invitation(round), rating: 4)
      Fabricate(:feedback_answer, feedback_question: rating_question,
        feedback_invitation: submitted_invitation(round), rating: 4)
      Fabricate(:feedback_answer, feedback_question: rating_question,
        feedback_invitation: submitted_invitation(round), rating: 1)

      expect(report.rating_counts(rating_question)).to eq({1 => 1, 2 => 0, 3 => 0, 4 => 2, 5 => 0})
    end

    it "ignores answers belonging to a non-submitted invitation" do
      pending_invitation = Fabricate(:feedback_invitation, feedback_round: round)
      Fabricate(:feedback_answer, feedback_question: rating_question,
        feedback_invitation: pending_invitation, rating: 5)

      expect(report.rating_counts(rating_question)).to eq({1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0})
    end
  end

  describe "#yes_no_counts" do
    it "tallies yes/no answers" do
      Fabricate(:feedback_answer, feedback_question: yes_no_question,
        feedback_invitation: submitted_invitation(round), rating: nil, yes_no: true)
      Fabricate(:feedback_answer, feedback_question: yes_no_question,
        feedback_invitation: submitted_invitation(round), rating: nil, yes_no: true)
      Fabricate(:feedback_answer, feedback_question: yes_no_question,
        feedback_invitation: submitted_invitation(round), rating: nil, yes_no: false)

      expect(report.yes_no_counts(yes_no_question)).to eq({true => 2, false => 1})
    end
  end

  describe "#text_answers" do
    it "returns non-blank text answers, in submission order" do
      optional_text_question = Fabricate(:feedback_question, kind: "text", position: 4,
        required: false)
      later = submitted_invitation(round)
      later.update!(submitted_at: 1.hour.from_now)
      earlier = submitted_invitation(round)
      earlier.update!(submitted_at: 1.hour.ago)
      blank = submitted_invitation(round)

      Fabricate(:feedback_answer, feedback_question: optional_text_question,
        feedback_invitation: later, rating: nil, text: "Später eingereicht")
      Fabricate(:feedback_answer, feedback_question: optional_text_question,
        feedback_invitation: earlier, rating: nil, text: "Früher eingereicht")
      Fabricate(:feedback_answer, feedback_question: optional_text_question,
        feedback_invitation: blank, rating: nil, text: "")

      expect(report.text_answers(optional_text_question))
        .to eq(["Früher eingereicht", "Später eingereicht"])
    end
  end

  context "aggregated across multiple courses" do
    let(:other_course) { Fabricate(:course, kind: Fabricate(:event_kind)) }
    let(:other_round) { Fabricate(:feedback_round, event: other_course, kind: "final") }

    subject(:report) { described_class.new(FeedbackRound.where(id: [round.id, other_round.id])) }

    it "combines answers across all given rounds/courses" do
      Fabricate(:feedback_answer, feedback_question: rating_question,
        feedback_invitation: submitted_invitation(round), rating: 5)
      Fabricate(:feedback_answer, feedback_question: rating_question,
        feedback_invitation: submitted_invitation(other_round), rating: 5)

      expect(report.courses).to contain_exactly(course, other_course)
      expect(report.rating_counts(rating_question)[5]).to eq(2)
    end
  end
end
