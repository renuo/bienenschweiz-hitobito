require "spec_helper"

RSpec.describe Api::Mobile::V1::SessionsController, type: :request do
  let!(:fachperson_produkte) { Fabricate(:person, authentication_token: '7xpaJOim8rbDH-ibP30GZQ') }

  def perform_call
      post api_mobile_v1_sessions_path, params: { user: { email: '', password: '' }, format: :json }
  end

  describe '#Fabricate' do
    context 'user is allowed from kas' do
      let(:cassette) { 'services/authentication_service_spec_ok' }

      context 'user has a quality fachperson_produkte role' do
        before do
          Fabricate(:role, type: Group::Inspektion::Inspektor.sti_name, person: fachperson_produkte, group: Group::Inspektion.first)
          perform_call
        end

        it 'returns ok' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns the user with intern structures' do
          expect(json_response['id']).to eq fachperson_produkte.id
          expect(json_response['inspectable_groups'].size).to eq fachperson_produkte.inspectable_groups.size
        end
      end

      context 'user does not have a quality fachperson_produkte role' do
        before { perform_call }

        it 'returns unathorized' do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context 'user is not allowed from kas' do
      let(:cassette) { 'services/authentication_service_spec_failed' }

      before { perform_call }

      it 'returns unathorized' do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
