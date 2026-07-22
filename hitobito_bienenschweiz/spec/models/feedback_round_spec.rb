# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe FeedbackRound do
  let(:event) { Fabricate(:course, kind: Fabricate(:event_kind)) }

  def participant_role_for(participation)
    Fabricate(Event::Course::Role::Participant.sti_name.to_sym, participation:)
  end

  it "is valid with an intermediate kind" do
    round = Fabricate.build(:feedback_round, event:)
    expect(round).to be_valid
  end

  it "renders to_s without a created_at (new, unsaved record)" do
    round = FeedbackRound.new(event:, kind: "intermediate")
    expect { round.to_s }.not_to raise_error
  end

  it "does not allow starting a round once a final round exists" do
    Fabricate(:feedback_round, event:, kind: "final")

    round = Fabricate.build(:feedback_round, event:, kind: "intermediate")
    expect(round).not_to be_valid
    expect(round.errors[:base]).to be_present
  end

  it "does not allow a second final round" do
    Fabricate(:feedback_round, event:, kind: "final")

    round = Fabricate.build(:feedback_round, event:, kind: "final")
    expect(round).not_to be_valid
  end

  it "generates an invitation for each active participant" do
    participation = Fabricate(:event_participation, event:, active: true)
    participant_role_for(participation)

    round = Fabricate(:feedback_round, event:, kind: "intermediate")

    expect(round.feedback_invitations.pluck(:participation_id)).to eq([participation.id])
  end

  it "does not invite leaders" do
    leader_participation = Fabricate(:event_participation, event:, active: true)
    Fabricate(Event::Role::Leader.sti_name.to_sym, participation: leader_participation)

    round = Fabricate(:feedback_round, event:, kind: "intermediate")

    expect(round.feedback_invitations).to be_empty
  end

  it "does not invite inactive (pending) participants" do
    pending_participation = Fabricate(:event_participation, event:, active: false)
    participant_role_for(pending_participation)

    round = Fabricate(:feedback_round, event:, kind: "intermediate")

    expect(round.feedback_invitations).to be_empty
  end

  it "guards the final-round check against a missing event instead of raising" do
    round = FeedbackRound.new(kind: "intermediate", event: nil)

    expect { round.valid? }.not_to raise_error
    expect(round.errors[:base]).to be_empty
  end
end
