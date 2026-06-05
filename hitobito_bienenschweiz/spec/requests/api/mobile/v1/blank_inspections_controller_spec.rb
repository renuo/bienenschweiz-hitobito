# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe Api::Mobile::V1::BlankInspectionsController, type: :request do
  let(:group) { groups(:kader_380) }
  let(:fachperson_produkte) { Fabricate(:fachperson_produkte, group_id: group.id) }
  let(:auth_headers) { {"Access-Token": fachperson_produkte.beeaudit_authentication_token} }

  describe "POST #create" do
    let!(:quality_control_question_1) { Fabricate(:quality_control_question) }
    let!(:quality_control_question_2) { Fabricate(:quality_control_question) }

    let(:quality_control_answer_1) do
      Fabricate.attributes_for(:quality_control_answer,
        quality_control_question_id: quality_control_question_1.id)
    end

    let(:quality_control_answer_2) do
      Fabricate.attributes_for(:quality_control_answer,
        quality_control_question_id: quality_control_question_2.id)
    end

    let(:new_member) do
      {
        first_name: Faker::Name.first_name, last_name: Faker::Name.last_name,
        street: Faker::Address.street_address, house_no: 1, zip: Faker::Address.zip,
        location: Faker::Address.city, email: Faker::Internet.email
      }
    end

    let(:qcontrol_params) do
      data = Fabricate.attributes_for(:recent_qcontrol).except(:group)
      data.merge(
        member: {},
        intern_structure_id: group.parent.id,
        quality_control_answers_attributes: [quality_control_answer_1, quality_control_answer_2]
      )
    end

    subject(:qcontrol) { assigns(:qcontrol) }

    context "without new person data" do
      it do
        post api_mobile_v1_blank_inspections_path,
          params: {inspection: qcontrol_params, format: :json}, headers: auth_headers
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with new person data" do
      before do
        post api_mobile_v1_blank_inspections_path,
          params: {inspection: qcontrol_params, member: new_member, format: :json},
          headers: auth_headers
      end

      it "creates a qcontrol and send the email" do
        expect(response).to have_http_status(:no_content)
        expect(Qcontrol.count).to eq(1)
        expect(InspectionMailer).to receive(:blank_inspection_info_mailer).and_call_original
        expect do
          post api_mobile_v1_blank_inspections_path,
            params: {inspection: qcontrol_params, member: new_member, format: :json},
            headers: auth_headers
          expect(response).to have_http_status(:no_content)
        end
          .to change { ActionMailer::Base.deliveries.count }.by(1)
          .and change { QualityControlAnswer.count }.by(2)
      end
    end

    context "when fachperson_produkte has multiple intern structures" do
      let(:sektion) { groups(:aargauisches_seetal) }
      let!(:beekeeper_membership) do
        siegelimker_group = Fabricate(:group, type: Group::Siegelimker.sti_name, parent: sektion)
        Fabricate(:role,
          type: Group::Siegelimker::Siegelimker.sti_name, person: fachperson_produkte,
          group: siegelimker_group, start_on: 1.day.ago, end_on: nil)
      end
      let(:fachperson_produkte_section) {
        fachperson_produkte.groups
          .where(type: Group::Kader.sti_name)
          .where(roles: {type: Group::Kader::FachpersonProdukte.sti_name}).first.parent
      }

      it "assigns the intern structure where the user is fachperson_produkte" do
        expect do
          post api_mobile_v1_blank_inspections_path,
            params: {inspection: qcontrol_params.except(:intern_structure_id),
                     member: new_member, format: :json},
            headers: auth_headers
          expect(response).to have_http_status(:no_content)
        end.to change(Qcontrol, :count).by(1)
        expect(Qcontrol.last.group).to eq fachperson_produkte_section
      end
    end

    context "when fachperson_produkte has multiple intern structures as honey chairman" do
      let!(:honey_chairman_membership) do
        kv_vorstand = Fabricate(:group, type: Group::KantonalverbandVorstand.sti_name,
          parent: groups(:aargauer_kantonalverband))
        Fabricate(:role,
          type: Group::KantonalverbandVorstand::Produkte.sti_name, person: fachperson_produkte,
          group: kv_vorstand, start_on: 2.years.ago, end_on: nil)
      end
      let(:fachperson_produkte_section) {
        fachperson_produkte.groups
          .where(type: Group::Kader.sti_name)
          .where(roles: {type: Group::Kader::FachpersonProdukte.sti_name}).first.parent
      }

      before do
        post api_mobile_v1_blank_inspections_path,
          params: {inspection: qcontrol_params.except(:intern_structure_id),
                   member: new_member, format: :json},
          headers: auth_headers
      end

      it "assigns the intern structure where the user is fachperson_produkte" do
        expect(Qcontrol.count).to eq(1)
        expect(Qcontrol.last.group).to eq fachperson_produkte_section
      end
    end

    context "with group_id" do
      let(:group_id_param) { group.parent.id }
      let(:send_request) do
        post api_mobile_v1_blank_inspections_path,
          params: {inspection: qcontrol_params.merge(intern_structure_id: group_id_param),
                   member: new_member, format: :json}, headers: auth_headers
      end

      it "stores the qcontrol with the requested intern structure" do
        expect do
          send_request
          expect(response).to have_http_status(:no_content)
        end.to change(Qcontrol, :count).by(1)
        expect(Qcontrol.last.group).to eq group.parent
      end

      context "when providing an invalid group_id" do
        let(:unrelated_group) { groups(:bienensolothurn) }
        let(:group_id_param) { unrelated_group.id }

        it "does not save the qcontrol and gives an error" do
          expect do
            send_request
          end.not_to change(Qcontrol, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body)
            .to include(I18n.t("activerecord.errors.messages.not_blank_inspectable"))
        end
      end
    end
  end
end
