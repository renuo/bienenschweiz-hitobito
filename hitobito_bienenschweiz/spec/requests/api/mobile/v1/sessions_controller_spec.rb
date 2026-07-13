# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe Api::Mobile::V1::SessionsController, type: :request do
  let(:email) { Faker::Internet.email }
  let(:password) { Faker::Internet.password(min_length: 12) }
  let!(:person) { Fabricate(:person, email:, password:) }

  def perform_call
    post api_mobile_v1_sessions_path, params: {user: {email:, password:}, format: :json}
  end

  describe "#create" do
    context "user sends valid credentials" do
      context "user has a quality fachperson_produkte role" do
        before do
          Fabricate(:role, type: Group::Kader::FachpersonProdukte, person:,
            group: groups(:kader_380))
          perform_call
        end

        it "returns ok" do
          expect(response).to have_http_status(:ok)
        end

        it "returns the user with intern structures" do
          expect(json_response["id"]).to eq person.id
          expect(json_response["inspectable_intern_structures"].size)
            .to eq person.inspectable_groups.size
        end
      end

      context "user does not have a quality person role" do
        before { perform_call }

        it "returns unathorized" do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context "user sends invalid crendentials" do
      let(:password) { "wrongpassword" }

      before { perform_call }

      it "returns unathorized" do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "user sends non-existent email" do
      before do
        post api_mobile_v1_sessions_path,
          params: {user: {email: "does.not.exist@example.com", password: "anything"},
                   format: :json}
      end

      it "returns unauthorized" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
