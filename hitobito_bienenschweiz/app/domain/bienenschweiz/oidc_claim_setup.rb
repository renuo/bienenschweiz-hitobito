# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

# Exposes whether a person has an active magazine subscription, so SSO clients
# (e.g. bienenzeitung.ch) can decide about access.
module Bienenschweiz::OidcClaimSetup
  def run
    super
    add_claim(:magazine_subscriber, scope: [:name, :with_roles]) do |owner|
      owner.magazine_subscriber?
    end
  end
end
