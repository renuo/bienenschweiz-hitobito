# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe Api::Mobile::V1::InspectionsController, type: :request do
  let!(:fachperson_produkte) { Fabricate(:fachperson_produkte, group_id: group.id) }
  let(:group) { groups(:kader_380) }
  let!(:other_group) { groups(:kader_383) }
  let(:beekeeper) { Fabricate(:beekeeper, group_id: group.parent.id) }
  let(:auth_headers) { {"Access-Token": fachperson_produkte.beeaudit_authentication_token} }

  describe "GET #index" do
    let!(:quality_controls1) {
      Fabricate.times(2, :due_soon_qcontrol, person_id: beekeeper.id,
        author_id: fachperson_produkte.id)
    }
    let!(:quality_controls2) {
      Fabricate.times(2, :due_soon_qcontrol, person_id: fachperson_produkte.id,
        author_id: fachperson_produkte.id)
    }

    context "beekeeper id is invalid" do
      subject! {
        get api_mobile_v1_beekeeper_inspections_path("12345"), params: {format: :json},
          headers: auth_headers
      }

      it { expect(response).to have_http_status :not_found }
      it { expect(response.body).to eq "" }
    end

    context "when beekeeper does not belong to the current fachperson_produkte" do
      subject! {
        get api_mobile_v1_beekeeper_inspections_path(other_beekeeper, format: :json),
          headers: auth_headers
      }

      let(:other_beekeeper) { Fabricate(:beekeeper, group_id: other_group.parent.id) }

      it { expect(response).to have_http_status :not_found }
    end

    context "beekeeper id is valid" do
      subject! {
        get api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json),
          headers: auth_headers
      }

      it { expect(response).to have_http_status :ok }
      it "only contains the controls of the passed beekeeper with the correct data" do
        expected_response = Qcontrol.where(person_id: beekeeper.id).order(control_date: :desc)
          .map(&:as_mobile_json)
        expected_response.each do |er|
          er["control_date"] = er["control_date"].to_s
        end
        expect(json_response).to eq expected_response
      end
    end
  end

  describe "GET #show" do
    let!(:quality_control) {
      Fabricate(:due_soon_qcontrol, person_id: beekeeper.id, author_id: fachperson_produkte.id)
    }
    let!(:answers) {
      Fabricate.times(5, :quality_control_answer, fulfilled: "passed", qcontrol: quality_control)
    }

    before { quality_control.quality_control_answers.reload }

    context "with invalid quality control id" do
      subject! {
        get api_mobile_v1_beekeeper_inspection_path(beekeeper, "12345", format: :json),
          headers: auth_headers
      }

      it { expect(response).to have_http_status :not_found }
    end

    context "with quality control belonging to other beekeeper" do
      subject! do
        get api_mobile_v1_beekeeper_inspection_path(
          other_beekeeper, quality_control, format: :json
        ), headers: auth_headers
      end

      let(:other_beekeeper) { Fabricate(:beekeeper, group_id: other_group.parent.id) }

      it { expect(response).to have_http_status :not_found }
    end

    context "with valid quality control id" do
      subject! do
        get api_mobile_v1_beekeeper_inspection_path(beekeeper, quality_control, format: :json),
          headers: auth_headers
      end

      it { expect(response).to have_http_status :ok }
      it "contains the correct fields and data" do
        expected_response = quality_control.as_full_mobile_json
        expected_response["control_date"] = expected_response["control_date"].to_s
        expect(json_response).to eq expected_response
      end
    end
  end

  describe "POST #create" do
    let(:quality_control_question_1) { Fabricate(:quality_control_question) }
    let(:quality_control_question_2) { Fabricate(:quality_control_question) }
    let(:not_existing_id) { 1000 }
    let(:quality_control_answer_1) do
      Fabricate.attributes_for(:quality_control_answer,
        quality_control_question_id: quality_control_question_1.id)
    end

    let(:quality_control_answer_2) do
      Fabricate.attributes_for(:quality_control_answer,
        quality_control_question_id: quality_control_question_2.id)
    end

    let(:qcontrol_params) do
      Fabricate.attributes_for(:recent_qcontrol)
        .except(:group, :author_name, :mass_import, :person_notified, :inspector_id).merge(
          intern_structure_id: group.parent.id,
          quality_control_answers_attributes: [quality_control_answer_1, quality_control_answer_2]
        )
    end

    let(:qcontrol_params_without_answers) do
      Fabricate.attributes_for(:recent_qcontrol).except(:group,
        :inspector_id).merge(intern_structure_id: group.parent.id)
    end

    subject(:qcontrol) { Qcontrol.last }

    context "not passed" do
      let(:quality_control_answer_1) do
        Fabricate.attributes_for(:quality_control_answer, fulfilled: "not_passed",
          quality_control_question_id: quality_control_question_1.id)
      end

      it "sends exactly two emails" do
        expect do
          post api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json),
            params: {inspection: qcontrol_params}, headers: auth_headers
        end.to have_enqueued_mail.exactly(2)
      end
    end

    context "passed" do
      let(:quality_control_answer_1) do
        Fabricate.attributes_for(:quality_control_answer, fulfilled: "passed",
          quality_control_question_id: quality_control_question_1.id)
      end

      it "sends exactly two emails" do
        expect do
          post api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json),
            params: {inspection: qcontrol_params}, headers: auth_headers
        end.to have_enqueued_mail.exactly(2)
      end
    end

    context "different beekeeper roles" do
      let!(:other_beekeeper) { Fabricate(:person) }
      let!(:unrelated_siegel_imker) { Fabricate(:siegel_imker_role) }

      before do
        siegelimker_group = Fabricate(:group, type: Group::Siegelimker.sti_name,
          parent: group.parent)
        Fabricate(:role,
          type: Group::Siegelimker::Siegelimker, person: other_beekeeper, group: siegelimker_group,
          start_on: 1.year.ago, end_on: nil)
      end

      it "creates with the correct section" do
        post api_mobile_v1_beekeeper_inspections_path(other_beekeeper, format: :json),
          params: {inspection: qcontrol_params}, headers: auth_headers
        expect(response).to have_http_status(:no_content)
        expect(qcontrol.group).to eq group.parent
      end
    end

    context "beekeeper with more roles" do
      let!(:other_beekeeper) { Fabricate(:person) }

      before do
        Fabricate(:role,
          type: Group::Kader::FachpersonProdukte, person: other_beekeeper,
          group_id: other_group.id, start_on: 1.year.ago, end_on: nil)
        siegelimker_group = Fabricate(:group, type: Group::Siegelimker.sti_name,
          parent: group.parent)
        Fabricate(:role,
          type: Group::Siegelimker::Siegelimker, person: other_beekeeper, group: siegelimker_group,
          start_on: 1.year.ago, end_on: nil)
      end

      it "assigns the correct intern structure" do
        post api_mobile_v1_beekeeper_inspections_path(other_beekeeper, format: :json),
          params: {inspection: qcontrol_params}, headers: auth_headers
        expect(response).to have_http_status(:no_content)
        expect(qcontrol.group).to eq group.parent
      end
    end

    context "beekeeper with more sections" do
      let!(:recent_group) { groups(:bienendorneck) }

      before do
        beekeeper.roles.first.update(end_on: 3.days.ago)
        Fabricate(:role, type: Group::Kader::FachpersonProdukte, person: fachperson_produkte,
          group_id: other_group.id, start_on: 3.days.ago, end_on: nil)
        recent_siegelimker = Fabricate(:group, type: Group::Siegelimker.sti_name,
          parent: recent_group)
        Fabricate(:role, type: Group::Siegelimker::Siegelimker, person: beekeeper,
          group: recent_siegelimker, start_on: 2.days.ago, end_on: nil)
        seetal_siegelimker = Fabricate(:group, type: Group::Siegelimker.sti_name,
          parent: other_group.parent)
        Fabricate(:role, type: Group::Siegelimker::Siegelimker, person: beekeeper,
          group: seetal_siegelimker, start_on: 3.days.ago, end_on: nil)
      end

      it "assigns the first valid intern structure ordered by start_on" do
        post api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json),
          params: {inspection: qcontrol_params}, headers: auth_headers
        expect(response).to have_http_status(:no_content)
        expect(qcontrol.group).to eq other_group.parent
      end
    end

    context "with valid data" do
      it "can ceate an inspection" do
        expect { post_inspection(qcontrol_params) }.to change(Qcontrol, :count)
        expect(response).to have_http_status(:no_content)
        expect(qcontrol.quality_control_answers.count).to eq 2
        expect(qcontrol.quality_control_answers[0])
          .to have_attributes(quality_control_answer_1.except(:qcontrol_id))
        expect(qcontrol.quality_control_answers[1])
          .to have_attributes(quality_control_answer_2.except(:qcontrol_id))
        is_expected.to have_attributes qcontrol_params.except(
          :quality_control_answers_attributes, :no_control_reason, :mass_import,
          :intern_structure_id, :group_id
        ).merge(
          author_name: "Beeaudit", certificate_printed: true
        )
        is_expected.to have_attributes group_id: group.parent_id
      end

      it { works_with(no_control_reason: "no_reason") }
      it { works_with(no_control_reason: "beekeeper_deceased") }
      it { works_with(no_control_reason: Qcontrol.no_control_reasons.except(:empty).values.sample) }
      it {
        works_with(no_control_reason: "termination_of_business",
          business_handover_to: Faker::Name.name)
      }
      it {
        works_with(no_control_reason: "resignation_from_certification_program",
          other_reason_for_no_control: Faker::Lorem.sentence)
      }

      it "sets with_voucher correctly" do
        qcontrol_params =
          Fabricate.attributes_for(:recent_qcontrol)
            .except(:group, :author_name, :mass_import).merge(
              group_id: group.id, with_voucher: true,
              quality_control_answers_attributes: [
                quality_control_answer_1,
                quality_control_answer_2
              ]
            )
        post_inspection(qcontrol_params)
        expect(Qcontrol.last.with_voucher?).to be true
      end
    end

    context "with an invalid answers set" do
      before do
        expect(QualityControlQuestion.all.map(&:id).include?(not_existing_id)).to eq false
        qcontrol_params[:quality_control_answers_attributes][0][:quality_control_question_id] =
          not_existing_id
        expect { post_inspection(qcontrol_params) }.to_not change(Qcontrol, :count)
      end

      it { expect(response).to have_http_status(:unprocessable_content) }
    end

    context "with invalid qcontrol data" do
      it "fails to Fabricate an inspection" do
        params_to_send = qcontrol_params_without_answers.merge(
          no_control_reason: Faker::Lorem.word
        )
        expect { post_inspection(params_to_send) }.to_not change(Qcontrol, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    def post_inspection(params_to_send)
      post api_mobile_v1_beekeeper_inspections_path(beekeeper, format: :json),
        params: {
          inspection: params_to_send
        },
        headers: auth_headers
    end

    def works_with(params_to_merge)
      params_to_send = qcontrol_params_without_answers.merge(params_to_merge)
      expect { post_inspection(params_to_send) }.to change(Qcontrol, :count)
      expect(response).to have_http_status(:no_content)
      is_expected.to have_attributes params_to_send.except(
        :quality_control_answers_attributes, :mass_import, :member_notified,
        :intern_structure_id, :group_id
      ).merge(
        author_name: "Beeaudit"
      )
    end
  end
end
