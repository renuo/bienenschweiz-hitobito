# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


require "spec_helper"

RSpec.describe Api::Mobile::V1::QualityControlQuestionsController, type: :request do
  let!(:fachperson_produkte) { Fabricate(:fachperson_produkte, group_id: groups(:produkte_380).id) }
  let!(:qc_section) { Fabricate(:quality_control_section, version: QualityControlSection.version) }
  let!(:qc_questions) {
    Fabricate.times(5, :quality_control_question, quality_control_section: qc_section)
  }
  let(:auth_headers) { {"Access-Token": fachperson_produkte.beeaudit_authentication_token} }

  before do
    get api_mobile_v1_quality_control_questions_path(format: :json), headers: auth_headers
  end

  it "it includes all the sections" do
    expect(response).to have_http_status(:ok)
    expect(json_response.length).to eq(QualityControlSection.count)
  end

  it "includes all the questions" do
    expect(json_response.first["quality_control_questions"]
               .count).to eq(qc_section.quality_control_questions.count)
    expect(json_response.first["quality_control_questions"]
             .pluck("number")).to eq(qc_questions.map(&:number))
  end

  it "sets the right data for the section" do
    expect(json_response.first["id"]).to eq(qc_section.id)
    expect(json_response.first["title"]).to eq(qc_section.title)
    expect(json_response.first["number"]).to eq(qc_section.number)
  end

  it "sets the right data for the question" do
    question = json_response.first["quality_control_questions"].first
    expect(question["id"]).to eq(qc_questions.first.id)
    expect(question["title"]).to eq(qc_questions.first.title)
    expect(question["description"]).to eq(qc_questions.first.description)
    expect(question["inspection_notes"]).to eq(qc_questions.first.inspection_notes)
    expect(question["number"]).to eq(qc_questions.first.number)
  end
end
