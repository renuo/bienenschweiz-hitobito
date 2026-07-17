# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe SupervisionTypesController, type: :request do
  let(:admin) { people(:admin) }
  let(:supervision_type) { supervision_types(:base_course) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "#index" do
    it "lists all supervision types" do
      get supervision_types_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(supervision_type.name)
    end
  end

  describe "#new" do
    it "renders the new form" do
      get new_supervision_type_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "#create" do
    it "creates a new supervision type and redirects to index" do
      expect do
        post supervision_types_path, params: {supervision_type: {name: "Neuer Kurs"}}
      end.to change { SupervisionType.count }.by(1)
      expect(response).to redirect_to(supervision_types_path(returning: true))
    end
  end

  describe "#edit" do
    it "renders the edit form" do
      get edit_supervision_type_path(supervision_type)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(supervision_type.name)
    end
  end

  describe "#update" do
    it "updates the supervision type and redirects to index" do
      patch supervision_type_path(supervision_type), params: {supervision_type: {name: "Umbenannt"}}
      expect(response).to redirect_to(supervision_types_path(returning: true))
      expect(supervision_type.reload.name).to eq("Umbenannt")
    end
  end

  describe "#destroy" do
    it "destroys the supervision type" do
      supervision_type # ensure it's loaded
      expect do
        delete supervision_type_path(supervision_type)
      end.to change { SupervisionType.count }.by(-1)
    end
  end

  describe "authorization" do
    context "as a non-admin user" do
      before { sign_in(Fabricate(:person)) }

      it "denies access to index" do
        expect { get supervision_types_path }.to raise_error(CanCan::AccessDenied)
      end

      it "denies access to create" do
        expect do
          post supervision_types_path, params: {supervision_type: {name: "Test"}}
        end.to raise_error(CanCan::AccessDenied)
      end

      it "denies access to update" do
        expect do
          patch supervision_type_path(supervision_type), params: {supervision_type: {name: "Test"}}
        end.to raise_error(CanCan::AccessDenied)
      end

      it "denies access to destroy" do
        expect do
          delete supervision_type_path(supervision_type)
        end.to raise_error(CanCan::AccessDenied)
      end
    end

    context "as a user with layer_and_below_full but without admin permission" do
      let(:sektion) { groups(:aarau_und_umgebung) }
      let(:sektion_admin_group) { groups(:sektion_admin_381) }
      let(:sektion_admin_person) do
        Fabricate(Group::SektionAdministrator::AdminSektion.name.to_sym,
          group: sektion_admin_group).person
      end

      before { sign_in(sektion_admin_person) }

      it "does not show the supervision_types nav link when accessing event_feed" do
        get event_feed_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(supervision_types_path)
      end
    end
  end
end
