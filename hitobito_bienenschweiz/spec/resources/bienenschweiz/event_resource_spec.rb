# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe EventResource, type: :resource do
  include Rails.application.routes.url_helpers
  let(:person) { people(:admin) }

  let(:event) { Fabricate(:event, export_to_website: false, event_type: "online") }

  it "includes export_to_website" do
    params[:filter] = {id: {eq: event.id}}
    render
    expect(jsonapi_data[0].attributes["export_to_website"]).to eq false
  end

  it "includes event_type" do
    params[:filter] = {id: {eq: event.id}}
    render
    expect(jsonapi_data[0].attributes["event_type"]).to eq "online"
  end

  it "filters by event_type" do
    Fabricate(:event, event_type: "internal")
    params[:filter] = {event_type: {eq: "online"}}
    event
    render
    expect(jsonapi_data.map(&:id)).to eq [event.id]
  end
end
