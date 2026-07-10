# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe PersonResource, type: :resource do
  include Rails.application.routes.url_helpers
  let(:person) { people(:admin) }

  let(:record) do
    Fabricate(:person, export_to_website: false).tap do |p|
      Fabricate(:role, person: p, group: groups(:root),
        type: Group::Dachverband::AdministratorBienenSchweiz.sti_name)
    end
  end

  it "includes export_to_website" do
    params[:filter] = {id: {eq: record.id}}
    render
    expect(jsonapi_data[0].attributes["export_to_website"]).to eq false
  end
end
