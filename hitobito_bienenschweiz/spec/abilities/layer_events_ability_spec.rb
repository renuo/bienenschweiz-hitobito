# frozen_string_literal: true

# Copyright (c) 2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe "layer_events permission" do
  subject(:ability) { Ability.new(user) }

  let(:user) { Fabricate(:person) }

  context "Group::SektionAdministrator::ErfassungVeranstaltungen" do
    let(:sektion) { groups(:aarau_und_umgebung) }
    let(:sektion_admin_group) { groups(:sektion_admin_381) }
    let(:other_sektion) { groups(:aargauisches_seetal) }

    before do
      Fabricate(Group::SektionAdministrator::ErfassungVeranstaltungen.sti_name.to_sym,
        group: sektion_admin_group, person: user)
    end

    context "on the sektion group itself" do
      it "may index events and courses" do
        expect(ability).to be_able_to(:index_events, sektion)
        expect(ability).to be_able_to(:"index_event/courses", sektion)
      end

      it "may export events and courses" do
        expect(ability).to be_able_to(:export_events, sektion)
        expect(ability).to be_able_to(:"export_event/courses", sektion)
      end

      it "may not export events on a group in a different sektion layer" do
        expect(ability).not_to be_able_to(:export_events, other_sektion)
        expect(ability).not_to be_able_to(:"export_event/courses", other_sektion)
      end
    end

    context "on events in the same sektion layer" do
      let(:event) { Fabricate(:event, groups: [sektion]) }

      it "may show and index participations" do
        expect(ability).to be_able_to(:show, event)
        expect(ability).to be_able_to(:index_participations, event)
        expect(ability).to be_able_to(:index_full_participations, event)
      end

      it "may create, update, and destroy" do
        new_event = sektion.events.new.tap { |e| e.groups << sektion }
        expect(ability).to be_able_to(:create, new_event)
        expect(ability).to be_able_to(:update, event)
        expect(ability).to be_able_to(:destroy, event)
      end

      it "may manage event participations" do
        participation = Fabricate(:event_participation, event: event)
        expect(ability).to be_able_to(:show_full, participation)
        expect(ability).to be_able_to(:update, participation)
        expect(ability).to be_able_to(:create, participation)
        expect(ability).to be_able_to(:destroy, participation)
      end
    end

    context "on events in a different sektion layer" do
      let(:other_event) { Fabricate(:event, groups: [other_sektion]) }

      it "may not update or destroy" do
        expect(ability).not_to be_able_to(:update, other_event)
        expect(ability).not_to be_able_to(:destroy, other_event)
      end

      it "may not manage participations" do
        participation = Fabricate(:event_participation, event: other_event)
        expect(ability).not_to be_able_to(:update, participation)
        expect(ability).not_to be_able_to(:destroy, participation)
      end
    end

    context "people and roles are not granted" do
      it "may not update people in the same layer" do
        other = Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: sektion_admin_group)
        expect(ability).not_to be_able_to(:update, other.person.reload)
      end

      it "may not manage roles in the same layer" do
        other = Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: sektion_admin_group)
        expect(ability).not_to be_able_to(:destroy, other)
      end
    end
  end

  context "Group::KantonalverbandAdministrator::VeranstaltungenKurse" do
    let(:kantonalverband) { groups(:aargauer_kantonalverband) }
    let(:kv_admin_group) do
      Fabricate(:group, type: Group::KantonalverbandAdministrator.sti_name,
        parent: kantonalverband)
    end
    let(:sektion_in_kv) { groups(:aarau_und_umgebung) }
    let(:other_kantonalverband) { groups(:berner_kantonalverband) }

    before do
      Fabricate(Group::KantonalverbandAdministrator::VeranstaltungenKurse.sti_name.to_sym,
        group: kv_admin_group, person: user)
    end

    context "on the kantonalverband group itself" do
      it "may index events and courses" do
        expect(ability).to be_able_to(:index_events, kantonalverband)
        expect(ability).to be_able_to(:"index_event/courses", kantonalverband)
      end

      it "may export events and courses" do
        expect(ability).to be_able_to(:export_events, kantonalverband)
        expect(ability).to be_able_to(:"export_event/courses", kantonalverband)
      end

      it "may not export events on a group in a different kantonalverband" do
        expect(ability).not_to be_able_to(:export_events, other_kantonalverband)
        expect(ability).not_to be_able_to(:"export_event/courses", other_kantonalverband)
      end
    end

    context "on events in the same kantonalverband layer" do
      let(:event) { Fabricate(:event, groups: [kantonalverband]) }

      it "may show and index participations" do
        expect(ability).to be_able_to(:show, event)
        expect(ability).to be_able_to(:index_participations, event)
        expect(ability).to be_able_to(:index_full_participations, event)
      end

      it "may create, update, and destroy" do
        new_event = kantonalverband.events.new.tap { |e| e.groups << kantonalverband }
        expect(ability).to be_able_to(:create, new_event)
        expect(ability).to be_able_to(:update, event)
        expect(ability).to be_able_to(:destroy, event)
      end

      it "may manage event participations" do
        participation = Fabricate(:event_participation, event: event)
        expect(ability).to be_able_to(:show_full, participation)
        expect(ability).to be_able_to(:update, participation)
        expect(ability).to be_able_to(:create, participation)
        expect(ability).to be_able_to(:destroy, participation)
      end
    end

    context "on events in a child sektion layer" do
      let(:sektion_event) { Fabricate(:event, groups: [sektion_in_kv]) }

      it "may not update or destroy (layer_events does not include below)" do
        expect(ability).not_to be_able_to(:update, sektion_event)
        expect(ability).not_to be_able_to(:destroy, sektion_event)
      end
    end

    context "on events in a different kantonalverband layer" do
      let(:other_event) { Fabricate(:event, groups: [other_kantonalverband]) }

      it "may not update or destroy" do
        expect(ability).not_to be_able_to(:update, other_event)
        expect(ability).not_to be_able_to(:destroy, other_event)
      end
    end

    context "people and roles are not granted" do
      it "may not update people in the same layer" do
        other = Fabricate(Group::KantonalverbandAdministrator::Kontakte.sti_name.to_sym,
          group: kv_admin_group)
        expect(ability).not_to be_able_to(:update, other.person.reload)
      end

      it "may not manage roles in the same layer" do
        other = Fabricate(Group::KantonalverbandAdministrator::Kontakte.sti_name.to_sym,
          group: kv_admin_group)
        expect(ability).not_to be_able_to(:destroy, other)
      end
    end
  end
end
