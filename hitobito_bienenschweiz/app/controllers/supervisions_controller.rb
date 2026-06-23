# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class SupervisionsController < CrudController
  self.nesting = Group, Person

  self.permitted_attrs = [:check_date, :supervisor_id, :kind, :supervision_type_id, :result,
    :document]

  decorates :group, :person

  # load parents before authorization
  prepend_before_action :parent
  before_render_form :load_supervisors

  def create
    entry.author = current_user
    super(location: index_path)
  end

  private

  def build_entry
    # default to a valid kind/result combination for the initial form state
    @person.supervisions.build(kind: "supervision", result: "fulfilled")
  end

  def load_supervisors
    @supervisors = Person.supervisors.order(:last_name, :first_name)
  end
end
