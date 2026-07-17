# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe "Event::KindsController", type: :request do
  let(:admin) { people(:admin) }
  let(:kind) { event_kinds(:dummy) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "GET #index" do
    it "displays abbreviation" do
      kind.update!(abbreviation: "GK")
      get event_kinds_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("GK")
    end
  end

  describe "PATCH #update" do
    it "saves abbreviation" do
      patch event_kind_path(kind), params: {event_kind: {abbreviation: "BK"}}
      expect(response).to redirect_to(event_kinds_path(returning: true))
      expect(kind.reload.abbreviation).to eq("BK")
    end

    it "rejects abbreviation longer than 5 characters" do
      patch event_kind_path(kind), params: {event_kind: {abbreviation: "TOOLONG"}}
      expect(response).to have_http_status(:unprocessable_content)
      expect(kind.reload.abbreviation).to be_nil
    end
  end
end
