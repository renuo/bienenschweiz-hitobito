# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe Api::Mobile::V1::InspectionPdfController, type: :request do
  let(:group) { groups(:kader_380) }
  let!(:fachperson_produkte) { Fabricate(:fachperson_produkte, group_id: group.id) }
  let(:beekeeper) { Fabricate(:beekeeper, group_id: group.parent.id) }
  let(:auth_headers) { {"Access-Token": fachperson_produkte.beeaudit_authentication_token} }

  let!(:qcontrol) do
    Fabricate(:qcontrol, person: beekeeper, group: group.parent,
      control_date: Date.new(2024, 1, 1), control_state: "passed")
  end

  describe "GET #show" do
    context "with a valid qcontrol belonging to an inspectable beekeeper" do
      it "returns the checklist PDF inline" do
        get api_mobile_v1_inspection_pdf_path(qcontrol), headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("application/pdf")
        expect(response.headers["Content-Disposition"]).to include("inline")
        expect(response.headers["Content-Disposition"]).to include("Betriebspruefung.pdf")
      end
    end

    context "with a non-existing id" do
      it "returns not found" do
        get api_mobile_v1_inspection_pdf_path("0"), headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a qcontrol belonging to a non-inspectable beekeeper" do
      let(:other_beekeeper) { Fabricate(:beekeeper, group_id: groups(:kader_383).parent.id) }
      let!(:other_qcontrol) do
        Fabricate(:qcontrol, person: other_beekeeper, group: groups(:kader_383).parent,
          control_date: Date.new(2024, 1, 1))
      end

      it "returns not found" do
        get api_mobile_v1_inspection_pdf_path(other_qcontrol), headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without an auth token" do
      it "returns unauthorized" do
        get api_mobile_v1_inspection_pdf_path(qcontrol)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an invalid auth token" do
      it "returns unauthorized" do
        get api_mobile_v1_inspection_pdf_path(qcontrol), headers: {"Access-Token": "invalid"}
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
