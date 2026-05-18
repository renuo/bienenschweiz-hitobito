# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

module Bienenschweiz::Person
  extend ActiveSupport::Concern

  included do
    has_many :qcontrols, dependent: :destroy

    QCONTROLLER_ROLES=[Group::Produkte::FachpersonProdukte.sti_name, Group::Produkte::FachpersonProdukteInAusbildung.sti_name]
    def qcontrol_inspector?
      roles.any? { |role| QCONTROLLER_ROLES.include?(role.type) }
    end

    def inspectable_groups
      groups.where(roles: {type: QCONTROLLER_ROLES}).map(&:parent)
    end
  end
end
