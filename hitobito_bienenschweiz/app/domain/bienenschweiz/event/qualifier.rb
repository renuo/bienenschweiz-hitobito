# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::Event::Qualifier
  # Participants completing a course whose kind grants it (Grundkurs) get a
  # Schnupper-Abo. The qualifications form re-issues all checked participations
  # on every save, so only the transition to qualified triggers it.
  def issue
    Qualification.transaction do
      grant_trial = trial_subscription_due?
      super
      MagazineSubscriptions::TrialSubscription.new(person).create if grant_trial
    end
  end

  private

  def trial_subscription_due?
    role == "participant" && participation.present? && !participation.qualified? &&
      event.kind.grants_trial_subscription?
  end
end
