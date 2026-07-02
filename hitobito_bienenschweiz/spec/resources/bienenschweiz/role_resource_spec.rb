# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe RoleResource, type: :resource do
  include Rails.application.routes.url_helpers
  let(:person) { people(:admin) }

  let(:role) do
    Fabricate(Group::Dachverband::AdministratorBienenSchweiz.sti_name,
      group: groups(:root),
      export_to_website: false)
  end

  it "includes export_to_website" do
    params[:filter] = {id: {eq: role.id}}
    render
    expect(jsonapi_data[0].attributes["export_to_website"]).to eq false
  end
end
