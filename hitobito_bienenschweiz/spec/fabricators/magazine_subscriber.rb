# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

Fabricator(:magazine_subscriber, from: :person) do
  after_create do |person|
    group = Group::BienenZeitung.first ||
      Fabricate(:group, type: Group::BienenZeitung.sti_name, parent: Group::Dachverband.first)
    Fabricate(:role, type: Group::BienenZeitung::Abonnent.sti_name, group:, person:)
  end
end
