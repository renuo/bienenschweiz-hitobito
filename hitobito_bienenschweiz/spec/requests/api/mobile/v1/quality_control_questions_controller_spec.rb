require "spec_helper"

RSpec.describe Api::Mobile::V1::QualityControlQuestionsController, type: :request do
  let!(:fachperson_produkte) { Fabricate(:person) }
  let!(:qc_section) { Fabricate(:quality_control_section, version: QualityControlSection.version) }
  let!(:qc_questions) { Fabricate.times(5, :quality_control_question, quality_control_section: qc_section) }
  let(:auth_headers) { { 'Access-Token': fachperson_produkte.authentication_token } }

  before do
    Fabricate(:role, type: Group::Inspektion::Inspektor.sti_name, person: fachperson_produkte, group: groups(:produkte_380))
    get api_mobile_v1_quality_control_questions_path(format: :json), headers: auth_headers
  end

  it 'it includes all the sections' do
    expect(json_response.length).to eq(QualityControlSection.count)
  end

  it 'includes all the questions' do
    expect(json_response.first['quality_control_questions']
               .count).to eq(qc_section.quality_control_questions.count)
    expect(json_response.first['quality_control_questions']
               .map { |row| row['number'] }).to eq(qc_questions.map(&:number))
  end

  it 'sets the right data for the section' do
    expect(json_response.first['id']).to eq(qc_section.id)
    expect(json_response.first['title']).to eq(qc_section.title)
    expect(json_response.first['number']).to eq(qc_section.number)
  end

  it 'sets the right data for the question' do
    expect(json_response.first['quality_control_questions'].first['id']).to eq(qc_questions.first.id)
    expect(json_response.first['quality_control_questions'].first['title']).to eq(qc_questions.first.title)
    expect(json_response.first['quality_control_questions'].first['description']).to eq(qc_questions.first.description)
    expect(json_response.first['quality_control_questions'].first['inspection_notes']).to eq(qc_questions.first.inspection_notes)
    expect(json_response.first['quality_control_questions'].first['number']).to eq(qc_questions.first.number)
  end
end
