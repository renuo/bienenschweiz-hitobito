# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe "Login", type: :request do
  context "/api/mobile/v1/sessions" do
    let!(:fachperson_produkte) {
      Fabricate(:fachperson_produkte, email: sent_email, password:)
    }
    let(:group) { groups(:kader_380) }
    let!(:role) {
      Fabricate(:role, type: Group::Kader::FachpersonProdukte.sti_name,
        person: fachperson_produkte,
        group:)
    }
    let(:password) { "changemechangeme" }

    before do
      post api_mobile_v1_sessions_path, params: {user: {email: sent_email, password: sent_password}}
    end

    subject { response }

    context "when logging in successfully" do
      let(:sent_email) { "auditor@kas.vdrb.ch" }
      let(:sent_password) { password }

      it { expect(subject.headers["Access-Token"]).to be_present }
      it { expect(subject).to have_http_status(:ok) }
      it "returns a valid signed_id" do
        person = Person.find_signed(subject.headers["Access-Token"], purpose: :beeaudit)
        expect(person).to eq(fachperson_produkte)
      end
    end

    context "when logging in unsuccessfully" do
      let(:sent_email) { "auditor@kas.vdrb.ch" }
      let(:sent_password) { "changeme2" }

      it { expect(subject.headers["Access-Token"]).to be_nil }
      it { expect(subject).to have_http_status(:unauthorized) }
    end
  end
end
