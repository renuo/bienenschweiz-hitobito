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

  it "retries token generation on a collision" do
    taken_token = invitation.token
    other_event = Fabricate(:course, kind: Fabricate(:event_kind))
    other_round = Fabricate(:feedback_round, event: other_event)
    other_participation = Fabricate(:event_participation, event: other_event, active: true)
    other = FeedbackInvitation.new(feedback_round: other_round, participation: other_participation)

    allow(SecureRandom).to receive(:urlsafe_base64).and_return(taken_token, "unique-token")
    other.save!

    expect(other.token).to eq("unique-token")
    expect(SecureRandom).to have_received(:urlsafe_base64).twice
  end

  it "does not set an event without a feedback_round" do
    without_round = FeedbackInvitation.new(participation: invitation.participation,
      feedback_round: nil)

    expect(without_round.event).to be_nil
    expect { without_round.save! }.to raise_error(ActiveRecord::NotNullViolation)
  end
end
