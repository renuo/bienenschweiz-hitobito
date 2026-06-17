# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_bienenschweiz.

module Bienenschweiz::Person
  extend ActiveSupport::Concern

  QCONTROLLER_ROLES = [
    Group::Kader::FachpersonProdukte.sti_name,
    Group::KantonalverbandVorstand::Produkte.sti_name
  ].freeze

  BEEKEEPER_ROLES = [
    Group::Siegelimker::Siegelimker.sti_name
  ]

  included do # rubocop:disable Metrics/BlockLength
    has_many :qcontrols, dependent: :destroy
    has_many :supervisions, dependent: :destroy

    def beeaudit_authentication_token
      signed_id(expires_in: 2.months, purpose: :beeaudit)
    end

    def qcontrol_inspector?
      roles.any? { |role| QCONTROLLER_ROLES.include?(role.type) }
    end

    def inspectable_beekeepers
      self.class.qcontrol_beekeepers_from(inspectable_groups)
    end

    scope :qcontrol_beekeepers_from, lambda { |sektionen|
      siegelimker_groups = Group.where(type: Group::Siegelimker.sti_name, parent_id: sektionen)
      active_roles = Role.active.where(group: siegelimker_groups, type: BEEKEEPER_ROLES)
      where(id: active_roles.select(:person_id))
    }

    scope :supervisors, lambda {
      supervisor_roles = Role.active
        .where(type: Group::ThemenbezogeneKontakte::Supervisor.sti_name)
      where(id: supervisor_roles.select(:person_id))
    }

    def inspectable_groups
      sorted_roles = roles.where(type: QCONTROLLER_ROLES).includes(:group).sort_by do |r|
        [r.is_a?(Group::Kader::FachpersonProdukte) ? 0 : 1, -r.start_on.to_time.to_i]
      end
      sorted_roles.flat_map { |r| sektionen_for_role(r) }.uniq
    end

    def inspectable_intern_structures
      # only used for mobile API to keep old data structure
      # MV used to just return all attributes but I reduced it to what it actually used in beeaudit
      inspectable_groups.map do |group|
        {
          "id" => group.id,
          "structure_type" => "sektion",
          "name" => group.name,
          "kanton" => group.canton_short
        }
      end
    end

    def as_mobile_json # rubocop:disable Metrics/MethodLength
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
        kanton: canton_short,
        birthdate: birthday,
        honey_yield:,
        hive_count:,
        telephone:,
        mobile:,
        email:
      }
    end

    def address_affixes
      address_care_of&.split(", ") || []
    end

    def full_address
      [street, housenumber].join(" ")
    end

    def telephone
      phone_numbers.where(label: :private).first&.number
    end

    def mobile
      phone_numbers.where(label: :mobile).first&.number
    end

    def canton_short
      canton&.upcase
    end

    def list_name
      full_name(:list)
    end

    private

    def sektionen_for_role(role)
      group = role.group
      if group.is_a?(Group::KantonalverbandVorstand)
        group.parent.children.where(type: Group::Sektion.sti_name).to_a
      else
        [group.parent]
      end
    end
  end
end
