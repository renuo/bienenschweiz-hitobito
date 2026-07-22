# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class FeedbackInvitationMailer < ApplicationMailer
  def self.invite_all(feedback_round)
    feedback_round.feedback_invitations.map { |invitation| invite(invitation) }
  end

  def invite(feedback_invitation)
    @feedback_invitation = feedback_invitation
    @event = feedback_invitation.event

    mail(
      to: feedback_invitation.person.email,
      subject: I18n.t("feedback_invitation_mailer.invite.subject", event: @event.name)
    )
  end
end
