# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe EventsController, type: :request do
  let(:admin) { people(:admin) }
  let(:kind) { Fabricate(:event_kind) }
  let(:course) { Fabricate(:course, kind: kind) }
  let(:group) { course.groups.first }

  before { sign_in(admin) }

  describe "GET /groups/:group_id/events/new" do
    it "shows a checkbox for the canceled field" do
      get new_group_event_path(groups(:root), event: {type: "Event::Course"})
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="event[canceled]"')
      expect(response.body).to include('type="checkbox"')
    end

    it "renders a tom-select for group selection without a hidden sentinel field" do
      get new_group_event_path(groups(:root), event: {type: "Event::Course"})
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="event[group_ids][]"')
      expect(response.body).to include('data-controller="tom-select"')
      # No hidden field means an empty selection submits no group_ids param,
      # preserving the old checkbox behaviour where deselecting all was a no-op.
      expect(response.body)
        .not_to match(/<input[^>]*type="hidden"[^>]*name="event\[group_ids\]\[\]"/)
    end

    it "only checks name as visible_contact_attribute by default" do
      get new_group_event_path(groups(:root), event: {type: "Event::Course"})
      expect(response).to have_http_status(:ok)

      name_input = response.body[
        /<input[^>]*name="event\[visible_contact_attributes\]\[name\]\]"[^>]*/
      ]
      expect(name_input).to include("checked")

      %w[picture address phone_number email social_account].each do |attr|
        input = response.body[
          /<input[^>]*name="event\[visible_contact_attributes\]\[#{attr}\]\]"[^>]*/
        ]
        expect(input).not_to include("checked")
      end
    end
  end

  describe "GET /groups/:group_id/events/:id/edit" do
    it "renders a tom-select for group selection with the current group pre-selected" do
      get edit_group_event_path(group, course)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="event[group_ids][]"')
      expect(response.body).to include('data-controller="tom-select"')
      expect(response.body).to match(/<option[^>]*selected[^>]*>/)
    end

    context "when the event belongs to a Sektion" do
      let(:sektion) { groups(:aarau_und_umgebung) }
      let(:sektion_course) { Fabricate(:course, kind: kind, groups: [sektion]) }

      it "renders successfully and populates the group select with all Sektionen" do
        get edit_group_event_path(sektion, sektion_course)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(sektion.name)
      end
    end
  end

  describe "kind restrictions by category layer_group_type" do
    let(:unrestricted_category) { Fabricate(:event_kind_category) }
    let(:dachverband_category) {
      Fabricate(:event_kind_category, layer_group_type: "Group::Dachverband")
    }
    let(:kantonalverband_category) {
      Fabricate(:event_kind_category, layer_group_type: "Group::Kantonalverband")
    }
    let(:sektion_category) { Fabricate(:event_kind_category, layer_group_type: "Group::Sektion") }

    let!(:kind_no_category) { Fabricate(:event_kind, label: "No Category Kind") }
    let!(:kind_unrestricted) {
      Fabricate(:event_kind, label: "Unrestricted Kind", kind_category: unrestricted_category)
    }
    let!(:kind_dachverband) {
      Fabricate(:event_kind, label: "Dachverband Kind", kind_category: dachverband_category)
    }
    let!(:kind_kantonalverband) {
      Fabricate(:event_kind, label: "Kantonalverband Kind", kind_category: kantonalverband_category)
    }
    let!(:kind_sektion) {
      Fabricate(:event_kind, label: "Sektion Kind", kind_category: sektion_category)
    }

    describe "GET /groups/:group_id/events/new" do
      context "for a Dachverband group" do
        before { get new_group_event_path(groups(:root), event: {type: "Event::Course"}) }

        it { expect(response.body).to include("No Category Kind") }
        it { expect(response.body).to include("Unrestricted Kind") }
        it { expect(response.body).to include("Dachverband Kind") }
        it { expect(response.body).not_to include("Kantonalverband Kind") }
        it { expect(response.body).not_to include("Sektion Kind") }
      end

      context "for a Kantonalverband group" do
        let(:kv_admin_group) do
          Fabricate(:group, type: Group::KantonalverbandAdministrator.sti_name,
            parent: groups(:aargauer_kantonalverband))
        end
        let(:kanton_admin) do
          Fabricate(Group::KantonalverbandAdministrator::AdminKanton.name.to_sym,
            group: kv_admin_group).person
        end

        before do
          sign_in(kanton_admin)
          get new_group_event_path(groups(:aargauer_kantonalverband),
            event: {type: "Event::Course"})
        end

        it { expect(response.body).to include("No Category Kind") }
        it { expect(response.body).to include("Unrestricted Kind") }
        it { expect(response.body).to include("Kantonalverband Kind") }
        it { expect(response.body).not_to include("Dachverband Kind") }
        it { expect(response.body).not_to include("Sektion Kind") }
      end

      context "for a Sektion group" do
        let(:sektion_admin) do
          Fabricate(Group::SektionAdministrator::AdminSektion.name.to_sym,
            group: groups(:sektion_admin_381)).person
        end

        before do
          sign_in(sektion_admin)
          get new_group_event_path(groups(:aarau_und_umgebung), event: {type: "Event::Course"})
        end

        it { expect(response.body).to include("No Category Kind") }
        it { expect(response.body).to include("Unrestricted Kind") }
        it { expect(response.body).to include("Sektion Kind") }
        it { expect(response.body).not_to include("Dachverband Kind") }
        it { expect(response.body).not_to include("Kantonalverband Kind") }
      end
    end

    describe "GET /groups/:group_id/events/:id/edit" do
      context "when the current kind is restricted to a different layer type than the group" do
        let(:restricted_course) {
          Fabricate(:course, kind: kind_kantonalverband, groups: [groups(:root)])
        }

        before { get edit_group_event_path(groups(:root), restricted_course) }

        it "still includes the current kind even though its category does not match" do
          expect(response.body).to include("Kantonalverband Kind")
        end

        it "still excludes other kinds restricted to non-matching types" do
          expect(response.body).not_to include("Sektion Kind")
        end
      end

      context "when the current kind matches the group's layer type" do
        let(:matching_course) {
          Fabricate(:course, kind: kind_dachverband, groups: [groups(:root)])
        }

        before { get edit_group_event_path(groups(:root), matching_course) }

        it "includes the current kind" do
          expect(response.body).to include("Dachverband Kind")
        end

        it "includes unrestricted kinds" do
          expect(response.body).to include("Unrestricted Kind")
        end

        it "excludes kinds restricted to other layer types" do
          expect(response.body).not_to include("Kantonalverband Kind")
        end
      end
    end
  end

  describe "GET /groups/:group_id/events (index)" do
    it "renders the events list" do
      get group_events_path(group)
      expect(response).to have_http_status(:ok)
    end

    it "renders the events list with Event::Course type filter" do
      get group_events_path(group, type: "Event::Course")
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /groups/:group_id/events/new with non-course event type" do
    it "renders the new form for a non-course event" do
      get new_group_event_path(groups(:root), event: {type: "Event"})
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /groups/:group_id/events/:id" do
    it "shows the state as open when no constraints are set" do
      get group_event_path(group, course)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t(:open, scope: "event_states"))
    end

    it "shows the state as canceled when the course is canceled" do
      course.update!(canceled: true)
      get group_event_path(group, course)
      expect(response.body).to include(I18n.t(:canceled, scope: "event_states"))
    end

    it "shows the state as expired when application_closing_at is in the past" do
      course.update!(application_closing_at: Date.current - 1.day)
      get group_event_path(group, course)
      expect(response.body).to include(I18n.t(:expired, scope: "event_states"))
    end

    it "shows the state as full when maximum_participants is reached" do
      course.update!(maximum_participants: 1)
      Fabricate(:event_participation, event: course)
      get group_event_path(group, course)
      expect(response.body).to include(I18n.t(:full, scope: "event_states"))
    end
  end

  describe "GET /groups/:group_id/events/:id tags section" do
    let(:sektion) { groups(:aarau_und_umgebung) }
    let(:sektion_course) { Fabricate(:course, kind: kind, groups: [sektion]) }

    # Has layer_read/layer_contacts in the sektion's layer (so :show is granted via
    # in_same_layer_or_public_or_participating), but no *_full tier, so :assign_tags is not.
    let(:contact_person) do
      Fabricate(Group::SektionAdministrator::Kontakte.sti_name.to_sym,
        group: groups(:sektion_admin_381)).person
    end

    it "shows the Tags section for someone who may assign tags, even without any tags" do
      get group_event_path(group, course)
      expect(response.body).to include("<dt class='muted'>Tags</dt>")
    end

    context "as a person who may not assign tags" do
      before { sign_in(contact_person) }

      it "hides the Tags section when the course has no tags" do
        get group_event_path(sektion, sektion_course)
        expect(response.body).not_to include("<dt class='muted'>Tags</dt>")
      end

      it "shows the Tags section (read-only) when the course already has tags" do
        sektion_course.tag_list.add("wichtig")
        sektion_course.save!

        get group_event_path(sektion, sektion_course)
        expect(response.body).to include("<dt class='muted'>Tags</dt>")
      end
    end
  end

  describe "GET /groups/:group_id/events/:id application attributes" do
    it "shows the application conditions when set" do
      course.update!(application_conditions: "Mindestalter 18 Jahre")
      get group_event_path(group, course)
      expect(response.body).to include("Aufnahmebedingungen")
      expect(response.body).to include("Mindestalter 18 Jahre")
    end

    it "hides the application conditions label when blank" do
      course.update!(application_conditions: "")
      get group_event_path(group, course)
      expect(response.body).not_to include("Aufnahmebedingungen")
    end

    it "shows the signature label when signature is true, and hides signature_confirmation" do
      # signature_confirmation implies signature (see Event#set_signature), so this also
      # covers signature_confirmation's false branch.
      course.update!(signature: true, signature_confirmation: false)
      get group_event_path(group, course)
      expect(response.body).to include("Unterschrift erforderlich")
      expect(response.body).not_to include("Zweitunterschrift erforderlich")
    end

    it "shows both signature labels when signature_confirmation is true" do
      course.update!(signature: true, signature_confirmation: true)
      get group_event_path(group, course)
      expect(response.body).to include("Unterschrift erforderlich")
      expect(response.body).to include("Zweitunterschrift erforderlich")
    end

    it "hides both signature labels when both are false" do
      course.update!(signature: false, signature_confirmation: false)
      get group_event_path(group, course)
      expect(response.body).not_to include("Unterschrift erforderlich")
      expect(response.body).not_to include("Zweitunterschrift erforderlich")
    end
  end
end
