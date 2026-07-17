# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe OrphanQcontrolsController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:admin) { people(:admin) }

  let(:beekeeper) { Fabricate(:person) }
  let!(:siegelimker_role) { Fabricate(:siegel_imker_role, person: beekeeper, sektion: sektion) }

  let!(:orphan) do
    Fabricate(:qcontrol, person: nil, group: sektion, control_date: Date.new(2024, 1, 1))
  end
  let!(:assigned) do
    Fabricate(:qcontrol, person: beekeeper, group: sektion, control_date: Date.new(2024, 2, 1))
  end

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "#index" do
    it "lists only orphan qcontrols" do
      get orphan_qcontrols_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("01.01.2024")
      expect(response.body).not_to include("01.02.2024")
    end

    it "includes Siegelimker people in the dropdown for the matching sektion" do
      get orphan_qcontrols_path
      expect(response.body).to include(beekeeper.list_name)
    end

    context "when orphan has an author Person" do
      let(:author) { Fabricate(:person, first_name: "Beeaudit", last_name: "App") }
      let!(:orphan_with_author) do
        Fabricate(:qcontrol, person: nil, group: sektion,
          control_date: Date.new(2024, 3, 1), author: author)
      end

      it "shows the author name" do
        get orphan_qcontrols_path
        expect(response.body).to include(author.to_s)
      end
    end

    context "when there are no orphan qcontrols" do
      before { orphan.destroy! }

      it "does not show the submit button" do
        get orphan_qcontrols_path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(I18n.t("orphan_qcontrols.index.update"))
      end
    end

    context "as non-admin" do
      let(:non_admin) { Fabricate(:person) }

      before { sign_in(non_admin) }

      it "raises access denied" do
        expect { get orphan_qcontrols_path }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe "#destroy" do
    it "destroys the orphan qcontrol" do
      expect do
        delete orphan_qcontrol_path(orphan)
      end.to change { Qcontrol.count }.by(-1)

      expect(response).to redirect_to(orphan_qcontrols_path)
    end

    it "sets a success flash on destroy" do
      delete orphan_qcontrol_path(orphan)
      expect(flash[:notice]).to be_present
    end

    it "sets an error flash when destroy fails" do
      allow_any_instance_of(Qcontrol).to receive(:destroy).and_return(false)
      delete orphan_qcontrol_path(orphan)
      expect(flash[:alert]).to be_present
    end
  end

  describe "#bulk_update" do
    it "assigns a Siegelimker person to an orphan qcontrol" do
      patch bulk_update_orphan_qcontrols_path,
        params: {qcontrols: {orphan.id.to_s => {person_id: beekeeper.id.to_s}}}

      expect(orphan.reload.person).to eq(beekeeper)
      expect(response).to redirect_to(orphan_qcontrols_path)
    end

    it "skips rows with blank person_id" do
      patch bulk_update_orphan_qcontrols_path,
        params: {qcontrols: {orphan.id.to_s => {person_id: ""}}}

      expect(orphan.reload.person).to be_nil
    end

    it "handles missing qcontrols param gracefully" do
      patch bulk_update_orphan_qcontrols_path
      expect(response).to redirect_to(orphan_qcontrols_path)
    end
  end
end
