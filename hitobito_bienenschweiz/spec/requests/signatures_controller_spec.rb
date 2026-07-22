# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe SignaturesController, type: :request do
  let(:admin) { people(:admin) }
  let(:signature) { signatures(:certificate_letter_1) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "#index" do
    it "renders without error" do
      get signatures_path
      expect(response).to have_http_status(:ok)
    end

    it "lists signature names" do
      get signatures_path
      expect(response.body).to include(signature.name)
    end

    it "does not render a new-signature link (route not available)" do
      get signatures_path
      expect(response.body).not_to match(%r{/signatures/new})
    end
  end

  describe "#edit" do
    it "renders the edit form without error" do
      get edit_signature_path(signature)
      expect(response).to have_http_status(:ok)
    end

    it "includes the signature name in the form" do
      get edit_signature_path(signature)
      expect(response.body).to include(signature.name)
    end
  end

  describe "#update" do
    it "updates name and title and redirects to index" do
      patch signature_path(signature),
        params: {signature: {name: "Neu Name", title: "Neue Funktion"}}
      expect(response).to redirect_to(signatures_path(returning: true))
      expect(signature.reload.name).to eq("Neu Name")
      expect(signature.reload.title).to eq("Neue Funktion")
    end

    it "re-renders edit on invalid params" do
      patch signature_path(signature), params: {signature: {name: ""}}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "authorization" do
    context "as a non-admin user" do
      before { sign_in(Fabricate(:person)) }

      it "denies index" do
        expect { get signatures_path }.to raise_error(CanCan::AccessDenied)
      end

      it "denies edit" do
        expect { get edit_signature_path(signature) }.to raise_error(CanCan::AccessDenied)
      end

      it "denies update" do
        expect do
          patch signature_path(signature), params: {signature: {name: "X"}}
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
