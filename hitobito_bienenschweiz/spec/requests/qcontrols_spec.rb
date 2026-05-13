# frozen_string_literal: true

#  Copyright (c) 2023, BienenSchweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require "spec_helper"

RSpec.describe QcontrolsController, type: :request do
  let(:root) { Group.root }
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:verband) { groups(:aargauer_kantonalverband) }
  let(:verband_inspektion) { Fabricate(:group, parent: root, type: Group::Inspektion.sti_name) }
  let(:admin) { people(:admin) }

  let(:beekeeper) {
    Fabricate(:person)
  }

  let(:inspector) {
    Fabricate(:person)
  }

  before do
    roles(:admin)
    sign_in(admin)
    Fabricate(:role, person: beekeeper, group: sektion, type: Group::Sektion::Siegelimker.sti_name)
    Fabricate(:role, person: inspector, group: verband_inspektion,
      type: Group::Inspektion::Inspektor.sti_name)
  end

  describe "#index" do
    let!(:qcontrols) {
      [
        Fabricate(:qcontrol, person: beekeeper, inspector: inspector, group: sektion,
          control_date: Date.new(2023, 1, 1), with_voucher: true),
        Fabricate(:qcontrol, person: beekeeper, inspector: inspector, group: sektion,
          control_date: Date.new(2023, 2, 1), with_voucher: false),
        Fabricate(:qcontrol, person: beekeeper, inspector: inspector, group: sektion,
          control_date: Date.new(2023, 3, 1), with_voucher: true),
        Fabricate(:qcontrol, person: beekeeper, inspector: inspector, group: sektion,
          control_date: Date.new(2023, 4, 1), with_voucher: false)
      ]
    }

    it "shows the qcontrols" do
      get group_person_qcontrols_path(sektion, beekeeper)
      expect(response).to have_http_status(:ok)
      qcontrols.each do |qcontrol|
        expect(response.body).to include(qcontrol.control_date.strftime("%d.%m.%Y"))
      end
    end
  end

  describe "#new" do
    it "renders the new qcontrol form" do
      get new_group_person_qcontrol_path(sektion, beekeeper)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Betriebsprüfung")
      expect(response.body).to include(inspector.full_name)
      expect(response.body).to include(sektion.name)
    end
  end

  describe "#create" do
    let(:qcontrol_params) do
      {
        group_id: sektion.id,
        inspector_id: inspector.id,
        control_date: Date.new(2023, 5, 1),
        with_voucher: true,
        control_state: "passed"
      }
    end

    before do
      Fabricate(:role, person: beekeeper, group: sektion,
        type: Group::Sektion::Siegelimker.sti_name)
    end

    it "creates a new qcontrol" do
      expect do
        post group_person_qcontrols_path(sektion, beekeeper), params: {qcontrol: qcontrol_params}
      end.to change { Qcontrol.count }.by(1)

      qcontrol = Qcontrol.last
      expect(qcontrol).to be_present
      expect(qcontrol.group).to eq(sektion)
      expect(qcontrol.person).to eq(beekeeper)
      expect(qcontrol.inspector).to eq(inspector)
      expect(qcontrol.control_date).to eq(Date.new(2023, 5, 1))
      expect(qcontrol.with_voucher).to eq(true)
      expect(qcontrol.control_state).to eq("passed")
    end

    context "when the params are invalid" do
      let(:qcontrol_params) do
        {
          group_id: sektion.id,
          inspector_id: inspector.id,
          control_date: nil, # invalid control date
          with_voucher: true,
          control_state: "passed"
        }
      end

      it "does not create a new qcontrol and renders the form with errors" do
        expect do
          post group_person_qcontrols_path(sektion, beekeeper), params: {qcontrol: qcontrol_params}
        end.not_to change { Qcontrol.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Betriebsprüfung")
        expect(response.body).to include("Kontrolldatum muss ausgefüllt werden")
      end
    end
  end

  describe "#destroy" do
    let!(:qcontrol) {
      Fabricate(:qcontrol, person: beekeeper, inspector: inspector, group: sektion,
        control_date: Date.new(2023, 1, 1), with_voucher: true)
    }

    it "destroys the qcontrol" do
      expect do
        delete group_person_qcontrol_path(sektion, beekeeper, qcontrol)
      end.to change { Qcontrol.count }.by(-1)
    end
  end
end
