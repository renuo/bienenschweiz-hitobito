require "spec_helper"

RSpec.describe Api::Mobile::V1::InspectionPdfController, type: :request do
  let(:fachperson_produkte) { Fabricate(:fachperson_produkte) }
  let(:group) { fachperson_produkte.groups.first }
  let(:beekeeper) { Fabricate(:beekeeper, group_id: group.id) }
  let(:auth_headers) { {"Access-Token": fachperson_produkte.authentication_token} }

  xdescribe "GET #show" do
    context "existing qcontrol" do
      let!(:quality_control) {
        Fabricate(:due_soon_qcontrol, member_id: beekeeper.id, author_id: fachperson_produkte.id)
      }
      let!(:answers) {
        Fabricate.times(5, :quality_control_answer, fulfilled: "passed", qcontrol: quality_control)
      }

      before { quality_control.quality_control_answers.reload }

      subject! {
        get api_mobile_v1_inspection_pdf_path(quality_control), params: {format: :json},
          headers: auth_headers
      }

      it { expect(response).to have_http_status :ok }
      it { expect(response.content_type).to eq "application/pdf" }
    end

    context "non-existing qcontrol" do
      subject! {
        get api_mobile_v1_inspection_pdf_path("12345"), params: {format: :json},
          headers: auth_headers
      }

      it { expect(response).to have_http_status :not_found }
    end

    context "qcontrol of a beekeeper who is not inspectable by the fachperson_produkte" do
      subject! {
        get api_mobile_v1_inspection_pdf_path(quality_control, format: :json), headers: auth_headers
      }

      let(:other_beekeeper) { Fabricate(:beekeeper, group_id: groups(:aarberg)) }
      let!(:quality_control) {
        Fabricate(:due_soon_qcontrol, member_id: other_beekeeper.id,
          author_id: fachperson_produkte.id)
      }

      it { expect(response).to have_http_status :not_found }
    end
  end
end
