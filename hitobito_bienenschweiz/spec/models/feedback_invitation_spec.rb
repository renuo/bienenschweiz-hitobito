# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

describe FeedbackInvitation do
  subject(:invitation) { Fabricate(:feedback_invitation) }

  it "generates a unique token on create" do
    expect(invitation.token).to be_present
  end

  it "denormalizes the event from its round" do
    expect(invitation.event).to eq(invitation.feedback_round.event)
  end

  it "exposes the invited person via the participation" do
    expect(invitation.person).to eq(invitation.participation.participant)
  end

  it "is not submitted by default" do
    expect(invitation).not_to be_submitted
  end

  it "is submitted once submitted_at is set" do
    invitation.update!(submitted_at: Time.zone.now)
    expect(invitation).to be_submitted
  end

  it "is not closed without a closes_at on the round" do
    expect(invitation).not_to be_closed
  end

  it "is closed once the round's closes_at is in the past" do
    invitation.feedback_round.update!(closes_at: 1.day.ago)
    expect(invitation).to be_closed
  end

  it "does not allow a second invitation for the same participation in the same round" do
    duplicate = Fabricate.build(:feedback_invitation,
      feedback_round: invitation.feedback_round,
      participation: invitation.participation)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:participation_id]).to be_present
  end
end
