# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe Event::ParticipationDecorator do
  # Only covers the defensive answer.question nil-safety branch, which never
  # reaches the actual rendering (content_tag/h.t) that needs a real view
  # context to resolve the relative translation key; see
  # spec/requests/event/participation_incomplete_label_spec.rb for the
  # relevance behaviour exercised through a real request.
  it "does not blow up on an orphaned answer without a question" do
    participation = Fabricate(:event_participation, active: true)
    orphaned_answer = Event::Answer.new(participation: participation, question: nil)
    allow(participation).to receive(:answers).and_return([orphaned_answer])

    expect(described_class.new(participation).incomplete_label).to be_nil
  end
end
