# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Bienenschweiz::Event::Qualifier
  # Participants completing a course whose kind grants it (Grundkurs) get a
  # Schnupper-Abo. The qualifications form re-issues all checked participations
  # on every save, so only the transition to qualified triggers it. #apply assigns
  # the submitted qualified flag before calling #issue and saves it afterwards.
  def issue
    grant_trial = trial_subscription_due?
    super
    MagazineSubscriptions::TrialSubscription.new(person).create if grant_trial
  end

  private

  def trial_subscription_due?
    role_kind == "participant" && !participation.qualified_in_database &&
      event.kind.grants_trial_subscription?
  end
end
