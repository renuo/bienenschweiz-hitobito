# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class Bienenschweiz::PersonAbility < AbilityDsl::Base
  on(Person) do
    permission(:layer_contacts)
      .may(:show_full, :show_details, :history, :read)
      .layer_contacts_in_same_layer
    permission(:layer_contacts).may(:show).layer_contacts_readable_in_same_layer
    permission(:layer_contacts)
      .may(:update, :primary_group, :send_password_instructions, :log, :approve_add_request,
        :show_tags, :create_tags, :assign_tags, :index_notes, :security)
      .layer_contacts_non_restricted_in_same_layer
    permission(:layer_contacts).may(:create).all
  end

  def layer_contacts_in_same_layer
    permission_in_layers?(subject.layer_group_ids)
  end

  def layer_contacts_readable_in_same_layer
    permission_in_layers?(subject.groups_with_roles_ended_readable.map(&:layer_group_id).uniq)
  end

  def layer_contacts_non_restricted_in_same_layer
    permission_in_layers?(subject.non_restricted_groups.collect(&:layer_group_id))
  end
end
