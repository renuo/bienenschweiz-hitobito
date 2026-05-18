# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class QcontrolsController < CrudController
  self.nesting = Group, Person

  self.permitted_attrs = [:group_id, :inspector_id, :control_date, :with_voucher, :control_state]

  decorates :group, :person

  # load parents before authorization
  prepend_before_action :parent
  before_render_form :load_inspectors
  before_render_form :load_sektionen

  # skip authorization for create to assign_attributes before authorization
  skip_authorize_resource only: [:create]

  def create
    assign_attributes
    authorize!(:create, entry)
    entry.author = current_user
    if Qcontrol.transaction { save_entry }
      redirect_to(group_person_path(@group, @person))
    else
      respond_with(entry)
    end
  end

  def destroy
    super(location: person_path(@person))
  end

  private

  def build_entry
    @person.qcontrols.build
  end

  def load_inspectors
    @inspectors = Person.joins(:roles).where(roles: {type: [Group::Inspektion::Inspektor.sti_name]})
  end

  def load_sektionen
    @sektionen = @person.groups.where(roles: {type: [Group::Sektion::Siegelimker.sti_name,
      Group::Sektion::SiegelimkerProvisorisch.sti_name]}).uniq
  end
end
