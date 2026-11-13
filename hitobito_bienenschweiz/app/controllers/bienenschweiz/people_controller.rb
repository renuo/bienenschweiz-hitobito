# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz::PeopleController
  extend ActiveSupport::Concern

  prepended do
    # Do not declare another `prepend_before_action :entry` here: Rails replaces the
    # core callback of the same name (and its `only:` list), which would leave @person
    # unloaded on show/edit/update so authorize_resource falls back to the Person class.
    # The action loads and authorizes the entry itself.
    skip_authorize_resource only: :spesen_sektion
  end

  # PUT button, ajax
  # Sets the Sektion used as fallback when creating KAS fees (Spesen) for courses that are
  # not given by a specific Sektion. Works like the primary group toggle.
  def spesen_sektion
    authorize!(:primary_group, entry)
    success = entry.update(spesen_sektion_id: params[:spesen_sektion_id])

    respond_to do |format|
      format.html { redirect_to group_person_path(group, entry) }
      format.js { render_spesen_sektion_js(success) }
    end
  end

  private

  def render_spesen_sektion_js(success)
    return render :primary_group if success

    flash.now.alert = I18n.t("global.errors.header", count: entry.errors.size)
    render "shared/update_flash"
  end
end
