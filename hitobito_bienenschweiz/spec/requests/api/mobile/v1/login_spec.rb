require "spec_helper"

RSpec.describe 'Login', type: :request do
  context '/api/mobile/v1/sessions' do
    let!(:fachperson_produkte) { Fabricate(:person, email: sent_email) }
    let(:group) { groups(:produkte_380) }
    let!(:role) { Fabricate(:role, type: Group::Inspektion::Inspektor.sti_name, person: fachperson_produkte, group:) }

    before do
        post api_mobile_v1_sessions_path, params: { user: { email: sent_email, password: sent_password } }
    end

    subject { response }
    context 'when logging in successfully' do
      let(:sent_email) { 'auditor@kas.vdrb.ch' }
      let(:sent_password) { 'changeme' }

      it { expect(subject.headers['Access-Token']).to eq '7xpaJOim8rbDH-ibP30GZQ' }
      it { expect(subject).to have_http_status(:ok) }
    end

    context 'when logging in unsuccessfully' do
      let(:sent_email) { 'auditor@kas.vdrb.ch' }
      let(:sent_password) { 'changeme2' }

      it { expect(subject.headers['Access-Token']).to be_nil }
      it { expect(subject).to have_http_status(:unauthorized) }
    end
  end
end
