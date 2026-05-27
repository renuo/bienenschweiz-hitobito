# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

module Bienenschweiz::Person
  extend ActiveSupport::Concern

  QCONTROLLER_ROLES = [
    Group::Produkte::FachpersonProdukte.sti_name,
    Group::Produkte::FachpersonProdukteInAusbildung.sti_name,
    Group::Kantonalverband::Honigobperson.sti_name,
    Group::Kantonalverband::HonigobpersonProvisorisch.sti_name,
  ].freeze

  BEEKEEPER_ROLES = [
    Group::Sektion::Siegelimker.sti_name,
    Group::Sektion::SiegelimkerProvisorisch.sti_name
  ]

  included do
    has_many :qcontrols, dependent: :destroy

    def qcontrol_inspector?
      roles.any? { |role| QCONTROLLER_ROLES.include?(role.type) }
    end

    def inspectable_beekeepers
      self.class.qcontrol_beekeepers_from(inspectable_groups)
    end

    scope :qcontrol_beekeepers_from, lambda { |group|
      where(id: Role.active.where(group: group, type: BEEKEEPER_ROLES).select(:person_id))
    }

    def inspectable_groups
      roles.
        where(type: QCONTROLLER_ROLES).
        includes(:group).
        sort_by do |role|
        [role.is_a?(Group::Produkte::FachpersonProdukte) ? 0 : 1, -role.start_on.to_time.to_i]
      end.map do |role|
        group = role.group
        if group.is_a?(Group::Kantonalverband)
          group.children.where(type: Group::Sektion.sti_name).to_a
        else
          group.parent
        end
      end.flatten.uniq
    end

    def inspectable_intern_structures
      # only used for mobile API to keep old data structure
      # MV used to just return all attributes but I reduced it to what it actually used in beeaudit
      inspectable_groups.map do |group|
        {
          "id" => group.id,
          "structure_type" => "sektion",
          "name" => group.name,
          "kanton" => group.canton
        }
      end
    end

    def as_mobile_json
      {
        id:,
        firstname: first_name,
        lastname: last_name,
        affix_1: address_affixes[0],
        affix_2: address_affixes[1],
        affix_3: address_affixes[2],
        street:,
        house_no: housenumber,
        zip: zip_code,
        location: town,
        kanton: canton,
        birthdate: birthday,
        honey_yield:,
        hive_count:,
        telephone:,
        mobile:,
        email:,
      }
    end

    def address_affixes
      address_care_of&.split(', ') || []
    end

    def full_address
      [street, housenumber].join(' ')
    end

    def telephone
      phone_numbers.where(label: :private).first&.number
    end

    def mobile
      phone_numbers.where(label: :mobile).first&.number
    end
  end
end
