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

  # Roles eligible to request Spesen (KAS fees). The Sektion of one of these roles is used
  # as the person's Spesen Sektion when a course is not given by a specific Sektion.
  SPESEN_ROLES = [
    Group::Kader::FachpersonBildung.sti_name,
    Group::Kader::FachpersonProdukte.sti_name,
    Group::Kader::FachpersonZuchtVermehrung.sti_name
  ].freeze

  included do # rubocop:disable Metrics/BlockLength
    belongs_to :spesen_sektion, class_name: "Group", optional: true

    validate :assert_spesen_sektion_eligible, if: :spesen_sektion_id_changed?

    has_many :qcontrols, dependent: :destroy
    has_many :supervisions, dependent: :destroy
    has_many :memos, dependent: :destroy
    has_many :magazine_subscriptions, dependent: :restrict_with_error
    has_one :siegelimker_profile, dependent: :destroy

    after_commit :geocode_siegelimker_profile, on: :update, if: lambda {
      (saved_changes.keys & %w[street housenumber zip_code town]).any?
    }

    def siegelimker?
      roles.any? { |role| BEEKEEPER_ROLES.include?(role.type) }
    end

    def beeaudit_authentication_token
      signed_id(expires_in: 2.months, purpose: :beeaudit)
    end

    def magazine_subscriber?
      magazine_subscriptions.active.exists?
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

    # Ids of the Sektionen in which the person has an active role eligible for Spesen,
    # ordered by the oldest role first.
    def spesen_sektion_ids
      layer_ids = ::Role.where(person_id: id, type: SPESEN_ROLES)
        .joins(:group).order("roles.id").pluck("groups.layer_group_id").uniq
      layer_ids & Group::Sektion.where(id: layer_ids).pluck(:id)
    end

    # Keeps the Spesen Sektion pointing to a Sektion with an eligible role: defaults to the
    # Sektion of the first eligible role and is un-set once no eligible role is left.
    def sync_spesen_sektion!
      ids = spesen_sektion_ids
      new_id = ids.include?(spesen_sektion_id) ? spesen_sektion_id : ids.first
      update_column(:spesen_sektion_id, new_id) if new_id != spesen_sektion_id # rubocop:disable Rails/SkipsModelValidations
    end

    private

    def assert_spesen_sektion_eligible
      return if spesen_sektion_id.nil? || spesen_sektion_ids.include?(spesen_sektion_id)

      errors.add(:spesen_sektion_id, :inclusion)
    end

    def geocode_siegelimker_profile
      profile = siegelimker_profile
      if profile && !profile.manual_coordinates?
        SiegelimkerProfileGeocodeJob.new(profile.id).enqueue!
      end
    end

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
