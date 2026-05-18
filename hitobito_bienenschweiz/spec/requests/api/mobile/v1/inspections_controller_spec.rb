require "spec_helper"

RSpec.describe Api::Mobile::V1::InspectionsController, type: :request do
  let!(:other_group) { groups(:aargauisches_seetal) }
  let!(:fachperson_produkte) { Fabricate(:fachperson_produkte) }
  let(:group) { fachperson_produkte.groups.first }
  let(:beekeeper) { Fabricate(:beekeeper, group_id: group.id) }
  let(:auth_headers) { { 'Access-Token': fachperson_produkte.authentication_token } }

  describe 'GET #index' do
    let!(:quality_controls1) { Fabricate.times(2, :due_soon_qcontrol, member_id: beekeeper.id, author_id: fachperson_produkte.id) }
    let!(:quality_controls2) { Fabricate.times(2, :due_soon_qcontrol, member_id: fachperson_produkte.id, author_id: fachperson_produkte.id) }

    context 'beekeeper id is invalid' do
      subject! { get api_mobile_v1_beekeeper_inspections_path('12345'), params: { format: :json }, headers: auth_headers }

      it { expect(response).to have_http_status :not_found }
      it { expect(response.body).to eq '' }
    end

    context 'when beekeeper does not belong to the current fachperson_produkte' do
      subject! { get api_mobile_v1_beekeeper_inspections_path(other_beekeeper, format: :json), headers: auth_headers }

      let(:other_beekeeper) { Fabricate(:beekeeper, group_id: other_group.id) }

      it { expect(response).to have_http_status :not_found }
    end

    context 'beekeeper id is valid' do
      subject! { get api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json), headers: auth_headers }

      it { expect(response).to have_http_status :ok }
      it 'only contains the controls of the passed beekeeper with the correct data' do
        expected_response = Qcontrol.where(member_id: beekeeper.id).order(control_date: :desc)
                                    .as_json(only: %i[id member_id author_id title control_date])
        expected_response.each do |er|
          er['control_date'] = er['control_date'].to_s
        end
        expect(json_response).to eq expected_response
      end
    end
  end

  describe 'GET #show' do
    let!(:quality_control) { Fabricate(:due_soon_qcontrol, member_id: beekeeper.id, author_id: fachperson_produkte.id) }
    let!(:answers) { Fabricate.times(5, :quality_control_answer, fulfilled: 'passed', qcontrol: quality_control) }

    before { quality_control.quality_control_answers.reload }

    context 'with invalid quality control id' do
      subject! { get api_mobile_v1_beekeeper_inspection_path(beekeeper, '12345', format: :json), headers: auth_headers }

      it { expect(response).to have_http_status :not_found }
    end

    context 'with quality control belonging to other beekeeper' do
      subject! do
        get api_mobile_v1_beekeeper_inspection_path(other_beekeeper, quality_control, format: :json),
            headers: auth_headers
      end

      let(:other_beekeeper) { Fabricate(:beekeeper, group_id: other_group.id) }

      it { expect(response).to have_http_status :not_found }
    end

    context 'with valid quality control id' do
      subject! do
        get api_mobile_v1_beekeeper_inspection_path(beekeeper, quality_control, format: :json), headers: auth_headers
      end

      it { expect(response).to have_http_status :ok }
      it 'contains the correct fields and data' do
        expected_response = quality_control.as_json(only: %i[id title document control_date no_control_reason
                                                             other_reason_for_no_control business_handover_to
                                                             with_voucher],
                                                    include: { person: { only: %i[id first_name last_name] },
                                                               author: { only: %i[id first_name last_name] },
                                                               group: { only: %i[id code name] },
                                                               quality_control_answers: { except: %i[updated_at
                                                                                                     Fabricated_at] } })
        expected_response['control_date'] = expected_response['control_date'].to_s
        # There was a breaking change in carrierwave, that leads to different
        # behavior for to_json and as_json:
        # https://github.com/carrierwaveuploader/carrierwave/pull/1481
        expected_response['document'] = { 'url' => nil }
        expect(json_response).to eq expected_response
      end
    end
  end

  describe 'POST #create' do
    let(:quality_control_question_1) { Fabricate(:quality_control_question) }
    let(:quality_control_question_2) { Fabricate(:quality_control_question) }
    let(:not_existing_id) { 1000 }
    let(:quality_control_answer_1) do
      Fabricate.attributes_for(:quality_control_answer, quality_control_question_id: quality_control_question_1.id)
    end

    let(:quality_control_answer_2) do
      Fabricate.attributes_for(:quality_control_answer, quality_control_question_id: quality_control_question_2.id)
    end

    let(:qcontrol_params) do
      Fabricate.attributes_for(:recent_qcontrol).except(:group, :author_name, :mass_import, :member_notified).merge(
        group_id: group.id,
        quality_control_answers_attributes: [quality_control_answer_1, quality_control_answer_2]
      )
    end

    let(:qcontrol_params_without_answers) do
      Fabricate.attributes_for(:recent_qcontrol).except(:group).merge(group_id: group.id)
    end

    subject(:qcontrol) { Qcontrol.last }

    context 'not passed' do
      let(:quality_control_answer_1) do
        Fabricate.attributes_for(:quality_control_answer, fulfilled: 'not_passed',
                                                quality_control_question_id: quality_control_question_1.id)
      end
      it 'sends exactly two emails' do
        expect do
          post api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json),
               params: { inspection: qcontrol_params }, headers: auth_headers
        end.to have_enqueued_mail.exactly(2)
      end
    end

    context 'passed' do
      let(:quality_control_answer_1) do
        Fabricate.attributes_for(:quality_control_answer, fulfilled: 'passed',
                                                quality_control_question_id: quality_control_question_1.id)
      end
      it 'sends exactly two emails' do
        expect do
          post api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json),
               params: { inspection: qcontrol_params }, headers: auth_headers
        end.to have_enqueued_mail.exactly(2)
      end
    end

    context 'different beekeeper roles' do
      let!(:other_beekeeper) { Fabricate(:person) }
      let!(:siegel_imker_role) { Fabricate(:siegel_imker_role) }
      let!(:temporary_siegel_imker_role) { Fabricate(:temporary_siegel_imker_role) }
      before do
        Fabricate(:membership,
               role: role, person: other_beekeeper, group_id: group.id,
               start_on: 1.year.ago, end_on: nil)
      end

      context 'siegel imker' do
        let(:role) { siegel_imker_role }
        it { Fabricates_with_correct_section }
      end

      context 'siegel imker provisorisch' do
        let(:role) { temporary_siegel_imker_role }
        it { Fabricates_with_correct_section }
      end

      def Fabricates_with_correct_section
        post api_mobile_v1_beekeeper_inspections_path(other_beekeeper, format: :json),
             params: { inspection: qcontrol_params }, headers: auth_headers
        expect(response).to have_http_status(:no_content)
        expect(qcontrol.group).to eq group
      end
    end

    context 'beekeeper with more roles' do
      let!(:other_beekeeper) { Fabricate(:person) }
      before do
        Fabricate(:membership,
               role: Role.fachperson_produkte, person: other_beekeeper, group_id: other_group.id,
               start_on: 1.year.ago, end_on: nil)
        Fabricate(:membership,
               role: Fabricate(:siegel_imker_role), person: other_beekeeper, group_id: group.id,
               start_on: 1.year.ago, end_on: nil)
      end

      it 'assigns the correct intern structure' do
        post api_mobile_v1_beekeeper_inspections_path(other_beekeeper, format: :json),
             params: { inspection: qcontrol_params }, headers: auth_headers
        expect(response).to have_http_status(:no_content)
        expect(qcontrol.group).to eq group
      end
    end

    context 'beekeeper with more sections' do
      let!(:recent_group) { Fabricate(:section) }
      before do
        beekeeper.roles.first.update(end_on: 3.days.ago)
        Fabricate(:membership, role: Role.fachperson_produkte, person: fachperson_produkte, group_id: other_group.id,
                            start_on: 3.days.ago, end_on: nil)
        Fabricate(:membership, role: Role.siegelimker, person: beekeeper, group_id: recent_group.id,
                            start_on: 2.days.ago, end_on: nil)
        Fabricate(:membership, role: Role.siegelimker, person: beekeeper, group_id: other_group.id,
                            start_on: 3.days.ago, end_on: nil)
      end

      it 'assigns the first valid intern structure ordered by start_on' do
        post api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json),
             params: { inspection: qcontrol_params }, headers: auth_headers
        expect(response).to have_http_status(:no_content)
        expect(qcontrol.group).to eq other_group
      end
    end

    context 'with valid data' do
      it 'can Fabricate an inspection' do
        expect { post_inspection(qcontrol_params) }.to change(Qcontrol, :count)
        expect(response).to have_http_status(:no_content)
        expect(qcontrol.quality_control_answers.count).to eq 2
        expect(qcontrol.quality_control_answers[0]).to have_attributes(quality_control_answer_1)
        expect(qcontrol.quality_control_answers[1]).to have_attributes(quality_control_answer_2)
        is_expected.to have_attributes qcontrol_params.except(
          :quality_control_answers_attributes, :no_control_reason, :mass_import
        ).merge(
          author_name: 'VDRB-APP', certificate_printed: true
        )
      end

      it { works_with(no_control_reason: 'no_reason') }
      it { works_with(no_control_reason: 'beekeeper_deceased') }
      it { works_with(no_control_reason: Qcontrol.no_control_reasons.except(:empty).values.sample) }
      it { works_with(no_control_reason: 'termination_of_business', business_handover_to: Faker::Name.name) }
      it { works_with(no_control_reason: 'resignation_from_certification_program', other_reason_for_no_control: Faker::Lorem.sentence) }

      it 'sets with_voucher correctly' do
        qcontrol_params =
          Fabricate.attributes_for(:recent_qcontrol).except(:group, :author_name, :mass_import).merge(
            group_id: group.id, with_voucher: true,
            quality_control_answers_attributes: [quality_control_answer_1, quality_control_answer_2]
          )
        post_inspection(qcontrol_params)
        expect(Qcontrol.last.with_voucher?).to be true
      end
    end

    context 'with an invalid answers set' do
      before do
        expect(QualityControlQuestion.all.map(&:id).include?(not_existing_id)).to eq false
        qcontrol_params[:quality_control_answers_attributes][0][:quality_control_question_id] = not_existing_id
        expect { post_inspection(qcontrol_params) }.to_not change(Qcontrol, :count)
      end

      it { expect(response).to have_http_status(:unprocessable_content) }
    end

    context 'with invalid qcontrol data' do
      it 'fails to Fabricate an inspection' do
        params_to_send =  qcontrol_params_without_answers.merge(
          no_control_reason: Faker::Lorem.word
        )
        expect { post_inspection(params_to_send) }.to_not change(Qcontrol, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    def post_inspection(params_to_send)
      post api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json), params: { inspection: params_to_send },
                                                                               headers: auth_headers
    end

    def works_with(params_to_merge)
      params_to_send = qcontrol_params_without_answers.merge(params_to_merge)
      expect { post_inspection(params_to_send) }.to change(Qcontrol, :count)
      expect(response).to have_http_status(:no_content)
      is_expected.to have_attributes params_to_send.except(
        :quality_control_answers_attributes, :mass_import, :member_notified
      ).merge(
        author_name: 'VDRB-APP'
      )
    end
  end
end
