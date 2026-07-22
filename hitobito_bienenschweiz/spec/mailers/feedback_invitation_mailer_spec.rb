# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe FeedbackInvitationMailer, type: :mailer do
  let(:event) { Fabricate(:course, kind: Fabricate(:event_kind), groups: [groups(:root)]) }
  let(:participant) { Fabricate(:person, email: "bea@example.com") }
  let(:round) { Fabricate(:feedback_round, event:) }
  let(:invitation) do
    participation = Fabricate(:event_participation, event:, active: true, participant:)
    Fabricate(:feedback_invitation, feedback_round: round, participation:)
  end

  describe "#invite" do
    subject(:mail) { described_class.invite(invitation) }

    it "sends to the invited participant" do
      expect(mail.to).to eq(["bea@example.com"])
    end

    it "includes the event name in the subject" do
      expect(mail.subject).to include(event.name)
    end

    it "includes a link to the feedback form in the body" do
      expect(mail.body.encoded).to include(invitation.token)
    end
  end

  describe ".invite_all" do
    it "returns one mail per invitation of the round" do
      invitation # ensure the first invitation exists
      other_participant = Fabricate(:person)
      other_participation = Fabricate(:event_participation, event:, active: true,
        participant: other_participant)
      Fabricate(:feedback_invitation, feedback_round: round, participation: other_participation)

      mails = described_class.invite_all(round)

      expect(mails.size).to eq(2)
      expect(mails.map { |m| m.to.first }).to contain_exactly("bea@example.com",
        other_participant.email)
    end
  end
end
