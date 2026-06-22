# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

class OrphanQcontrolsController < ApplicationController
  before_action :authorize_action

  def index
    @qcontrols = Qcontrol.orphan.includes(:group, :author).order(control_date: :desc)
    @people_by_sektion = load_people_by_sektion(@qcontrols)
  end

  def destroy
    qcontrol = Qcontrol.find(params[:id])
    if qcontrol.destroy
      flash[:notice] = t(".success")
    else
      flash[:alert] = t(".error")
    end
    redirect_to orphan_qcontrols_path
  end

  def bulk_update
    params[:qcontrols]&.each do |qcontrol_id, qcontrol_params|
      person_id = qcontrol_params[:person_id]
      next if person_id.blank?

      Qcontrol.find(qcontrol_id.to_i).update(person_id: person_id)
    end
    redirect_to orphan_qcontrols_path
  end

  private

  def authorize_action
    authorize!(:manage_orphans, Qcontrol)
  end

  def load_people_by_sektion(qcontrols)
    sektion_ids = qcontrols.map(&:group_id).uniq
    sektion_ids.each_with_object({}) do |sektion_id, map|
      siegelimker_group_ids = Group::Siegelimker.where(parent_id: sektion_id).select(:id)
      map[sektion_id] = Person.joins(:roles)
        .where(roles: {
          type: Group::Siegelimker::Siegelimker.sti_name,
          group_id: siegelimker_group_ids
        })
        .order(:last_name, :first_name)
        .distinct
        .to_a
    end
  end
end
