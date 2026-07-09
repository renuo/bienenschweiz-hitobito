# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe EventsController, type: :request do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }
  let(:other_person) { Fabricate(:person) }
  let(:kind) { Fabricate(:event_kind) }
  let(:course) do
    Fabricate(:course, kind: kind, groups: [group],
      delivery_address: "Musterstrasse 1\n3000 Bern",
      billing_address: "Buchhaltung AG\n8000 Zürich")
  end

  describe "GET #index (courses)" do
    context "as admin with create permission" do
      before do
        roles(:admin)
        sign_in(admin)
      end

      context "when a kind has a template file" do
        around do |example|
          template_dir = HitobitoBienenschweiz::Wagon.root.join("config", "event_kind_templates")
          template_file = template_dir.join("#{kind.id}.yml")
          template_file.write({"description" => "Test"}.to_yaml)
          example.run
        ensure
          template_file.delete if template_file.exist?
        end

        it "shows the new_from_kind dropdown" do
          get group_events_path(group, type: "Event::Course")
          expect(response.body).to include(new_from_kind_group_events_path(group,
            event_kind_id: kind.id))
        end
      end

      context "when no kind has a template file" do
        it "does not show the new_from_kind dropdown" do
          get group_events_path(group, type: "Event::Course")
          expect(response.body).not_to include("new_from_kind")
        end
      end
    end
  end

  describe "GET #new_from_kind" do
    let(:kind) { Fabricate(:event_kind) }

    context "as admin with create permission" do
      before do
        roles(:admin)
        sign_in(admin)
      end

      it "renders the new course form" do
        get new_from_kind_group_events_path(group, event_kind_id: kind.id)
        expect(response).to have_http_status(:ok)
      end

      it "prefills kind_id" do
        get new_from_kind_group_events_path(group, event_kind_id: kind.id)
        expect(response.body).to include(kind.id.to_s)
      end

      context "with a template file for the kind" do
        let(:template_data) do
          {
            "description" => "Prefilled description",
            "location" => "Prefilled location",
            "required_contact_attrs" => ["phone_numbers"],
            "hidden_contact_attrs" => ["nickname"],
            "application_questions" => [{"question" => "Wie viele Völker?", "required" => true}],
            "admin_questions" => [{"question" => "Bestätigt?", "required" => false}]
          }
        end

        around do |example|
          template_dir = HitobitoBienenschweiz::Wagon.root.join("config", "event_kind_templates")
          template_file = template_dir.join("#{kind.id}.yml")
          template_file.write(template_data.to_yaml)
          example.run
        ensure
          template_file.delete if template_file.exist?
        end

        it "prefills description from template" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include("Prefilled description")
        end

        it "prefills location from template" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include("Prefilled location")
        end

        it "prefills application questions from template" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include("Wie viele Völker?")
        end

        it "prefills admin questions from template" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include("Bestätigt?")
        end

        it "marks required_contact_attrs as required" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include(
            'id="event_contact_attrs_phone_numbers_required" value="required" checked="checked"'
          )
        end

        it "marks hidden_contact_attrs as hidden" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include(
            'id="event_contact_attrs_nickname_hidden" value="hidden" checked="checked"'
          )
        end
      end
    end

    context "as person without create permission" do
      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe "GET #course_materials" do
    context "as admin with update permission" do
      before do
        roles(:admin)
        sign_in(admin)
      end

      it "renders successfully" do
        get group_event_course_materials_path(group, course)
        expect(response).to have_http_status(:ok)
      end

      it "shows the delivery address" do
        get group_event_course_materials_path(group, course)
        expect(response.body).to include("Musterstrasse 1")
      end

      it "shows the billing address" do
        get group_event_course_materials_path(group, course)
        expect(response.body).to include("Buchhaltung AG")
      end
    end

    context "as person without update permission" do
      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect do
          get group_event_course_materials_path(group, course)
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
