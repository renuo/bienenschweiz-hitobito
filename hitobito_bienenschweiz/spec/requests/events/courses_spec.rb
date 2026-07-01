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

    it "renders a tom-select for group selection" do
      get new_group_event_path(groups(:root), event: {type: "Event::Course"})
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="event[group_ids][]"')
      expect(response.body).to include('data-controller="tom-select"')
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
end
