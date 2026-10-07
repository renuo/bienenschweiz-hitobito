# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class TrialSubscriptionMailer < ApplicationMailer
  def manual_review(person, subscriptions)
    @person = person
    @subscriptions = subscriptions
    mail(to: ENV.fetch("SECRETARY_EMAIL", nil), # rubocop:disable Rails/EnvironmentVariableAccess
      subject: "Schnupper-Abo: manuelle Prüfung für #{person.full_name}")
  end
end
