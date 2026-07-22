# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe FeedbackQuestion do
  subject(:question) { Fabricate.build(:feedback_question, kind:, required: true) }

  let(:answer) { Fabricate.build(:feedback_answer, feedback_question: question) }

  context "rating question" do
    let(:kind) { "rating" }

    it "rejects a missing rating when required" do
      answer.rating = nil
      question.validate_answer(answer)
      expect(answer.errors[:rating]).to be_present
    end

    it "rejects a rating outside 1..5" do
      answer.rating = 6
      question.validate_answer(answer)
      expect(answer.errors[:rating]).to be_present
    end

    it "accepts a rating between 1 and 5" do
      answer.rating = 3
      question.validate_answer(answer)
      expect(answer.errors[:rating]).to be_empty
    end

    it "allows a missing rating when the question is not required" do
      question.required = false
      answer.rating = nil
      question.validate_answer(answer)
      expect(answer.errors[:rating]).to be_empty
    end
  end

  context "yes_no question" do
    let(:kind) { "yes_no" }

    it "rejects a missing answer when required" do
      answer.yes_no = nil
      question.validate_answer(answer)
      expect(answer.errors[:yes_no]).to be_present
    end

    it "accepts false as a valid answer" do
      answer.yes_no = false
      question.validate_answer(answer)
      expect(answer.errors[:yes_no]).to be_empty
    end
  end

  context "text question" do
    let(:kind) { "text" }

    it "rejects a blank answer when required" do
      answer.text = ""
      question.validate_answer(answer)
      expect(answer.errors[:text]).to be_present
    end

    it "accepts a present answer" do
      answer.text = "Sehr guter Kurs"
      question.validate_answer(answer)
      expect(answer.errors[:text]).to be_empty
    end
  end
end
