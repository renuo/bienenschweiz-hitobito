# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe "Event::RolesController", type: :request do
  let(:admin) { people(:admin) }
  let(:group) { admin.groups.first }
  let(:role) { event_roles(:top_leader) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "GET #new" do
    it "doesn't show the checkbox to remove participant roles" do
      get new_group_event_role_path(group, group.events.first,
        event_role: {type: Event::Role::Leader.sti_name})

      expect(response.body)
        .not_to include(Event::Role.human_attribute_name(:remove_participant_role))
    end
  end

  describe "POST #create" do
    let(:participant) { Fabricate(:person) }

    [:root, :aargauer_kantonalverband, :aarau_und_umgebung].each do |group_key|
      context "with a course in #{group_key}" do
        let(:group) { groups(group_key) }
        let(:course) { Fabricate(:course, groups: [group], kind: Fabricate(:event_kind)) }

        it "adds a participant" do
          expect do
            post group_event_roles_path(group, course), params: {
              event_role: {type: Event::Course::Role::Participant.sti_name,
                           person_id: participant.id}
            }
          end.to change { course.participations.count }.by(1)

          participation = course.participations.find_by(participant: participant)
          expect(participation.roles.map(&:class)).to eq([Event::Course::Role::Participant])
        end
      end
    end
  end
end
