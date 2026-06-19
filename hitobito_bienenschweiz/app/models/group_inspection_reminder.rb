# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class GroupInspectionReminder
  attr_reader :group, :inspectors, :created_at

  def initialize(group, inspectors)
    @group = group
    @inspectors = inspectors
    @created_at = Time.zone.now
  end

  # Used by InspectionService to skip groups with no active Siegelimkers
  def any?
    siegelimker_groups = Group.where(type: Group::Siegelimker.sti_name, parent_id: sektion_ids)
    Person.joins(:roles)
      .where(roles: {type: Group::Siegelimker::Siegelimker.sti_name, group: siegelimker_groups})
      .merge(Role.active)
      .exists?
  end

  def inspector_emails
    inspectors.filter_map(&:email)
  end

  def president_emails
    vorstand_types = [Group::SektionVorstand.sti_name, Group::KantonalverbandVorstand.sti_name]
    praesident_types = [
      Group::SektionVorstand::Praesident.sti_name,
      Group::KantonalverbandVorstand::Praesident.sti_name
    ]
    vorstand_groups = Group.where(type: vorstand_types, parent_id: group.id)
    Person.joins(:roles)
      .where(roles: {type: praesident_types, group: vorstand_groups})
      .merge(Role.active)
      .distinct
      .filter_map(&:email)
  end

  def related_member_data
    return [] if sektion_ids.empty?

    query_siegelimkers.map do |person|
      control_date = person.max_control_date&.to_date
      [
        person.sektion_name,
        person.last_name.to_s,
        person.first_name.to_s,
        person.address_affixes[0].to_s,
        person.full_address.to_s,
        person.zip_code.to_s,
        person.town.to_s,
        person.telephone,
        person.mobile,
        person.email,
        (control_date || Time.zone.at(0).to_date).strftime("%d.%m.%Y")
      ]
    end
  end

  private

  def sektion_ids
    @sektion_ids ||= if group.is_a?(Group::Kantonalverband)
      group.children.where(type: Group::Sektion.sti_name).pluck(:id)
    else
      [group.id]
    end
  end

  def query_siegelimkers
    Person
      .joins(<<~SQL)
        INNER JOIN roles AS si_roles
          ON si_roles.person_id = people.id
          AND si_roles.type = '#{Group::Siegelimker::Siegelimker.sti_name}'
          AND (si_roles.end_on IS NULL OR si_roles.end_on >= '#{Date.current}')
          AND (si_roles.start_on IS NULL OR si_roles.start_on <= '#{Date.current}')
        INNER JOIN groups AS si_groups
          ON si_groups.id = si_roles.group_id
          AND si_groups.type = '#{Group::Siegelimker.sti_name}'
          AND si_groups.deleted_at IS NULL
        INNER JOIN groups AS sektionen
          ON sektionen.id = si_groups.parent_id
          AND sektionen.deleted_at IS NULL
      SQL
      .where(sektionen: {id: sektion_ids})
      .left_joins(:qcontrols)
      .select("people.*, sektionen.name AS sektion_name, MAX(qcontrols.control_date) AS max_control_date")
      .group("people.id, sektionen.name")
      .order(Arel.sql("sektionen.name ASC, max_control_date ASC NULLS FIRST"))
  end
end
