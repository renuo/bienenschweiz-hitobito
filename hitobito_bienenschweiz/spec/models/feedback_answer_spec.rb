# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe FeedbackAnswer do
  subject(:answer) { Fabricate(:feedback_answer) }

  it "is valid with a matching rating" do
    expect(answer).to be_valid
  end

  it "delegates validation to the feedback_question" do
    answer.rating = 42
    expect(answer).not_to be_valid
    expect(answer.errors[:rating]).to be_present
  end

  it "exposes the type-appropriate value" do
    expect(answer.value).to eq(answer.rating)
  end

  it "is not valid with a duplicate question for the same invitation" do
    answer.save!
    duplicate = Fabricate.build(:feedback_answer,
      feedback_invitation: answer.feedback_invitation,
      feedback_question: answer.feedback_question)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:feedback_question_id]).to be_present
  end
end
