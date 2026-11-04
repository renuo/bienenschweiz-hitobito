# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz::GroupDecorator
  # Renders the Spesen Sektion toggle next to the primary group star.
  def primary_group_toggle_link(person, group, **)
    helpers.safe_join([super, spesen_sektion_toggle_link(person, group)].compact, " ")
  end

  def spesen_sektion_toggle_link(person, group)
    return unless spesen_sektion_selectable?(person) && can?(:primary_group, person)

    selected = person.spesen_sektion_id == model.layer_group_id
    title = I18n.t("people.roles_aside.#{selected ? "spesen_sektion" : "set_spesen_sektion"}")
    icon = helpers.icon(:money_bill_1, filled: selected)
    path = helpers.spesen_sektion_group_person_path(group, person,
      spesen_sektion_id: model.layer_group_id)
    attrs = {title: title, alt: title, class: "spesen-sektion-#{model.id}"}
    helpers.link_to(icon, path, attrs.merge(data: {method: :put, remote: true}))
  end

  private

  # Only groups in which the person has a role eligible for Spesen and that belong to
  # a Sektion layer can be chosen.
  def spesen_sektion_selectable?(person)
    person.roles.any? do |role|
      role.group_id == model.id && Bienenschweiz::Person::SPESEN_ROLES.include?(role.type)
    end && model.layer_group.is_a?(Group::Sektion)
  end
end
