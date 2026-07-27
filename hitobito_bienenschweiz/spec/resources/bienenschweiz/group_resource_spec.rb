# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe GroupResource, type: :resource do
  include Rails.application.routes.url_helpers
  let(:person) { people(:admin) }

  let(:group) { Fabricate(:group, code: 1234, type: Group::Kantonalverband.sti_name) }

  it "includes code" do
    params[:filter] = {id: {eq: group.id}}
    render
    expect(jsonapi_data[0].attributes["code"]).to eq 1234
  end

  it "includes member_count as the manually entered value for a Sektion" do
    sektion = Fabricate(:sektion, parent: groups(:aargauer_kantonalverband), member_count: 9)

    params[:filter] = {id: {eq: sektion.id}}
    render
    expect(jsonapi_data[0].attributes["member_count"]).to eq 9
  end

  it "includes member_count as the sum of descendant Sektionen for a Kantonalverband" do
    Fabricate(:sektion, parent: group, member_count: 12)

    params[:filter] = {id: {eq: group.id}}
    render
    expect(jsonapi_data[0].attributes["member_count"]).to eq 12
  end
end
