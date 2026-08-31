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

  describe "GET #index (events)" do
    let(:template_dir) { HitobitoBienenschweiz::Wagon.root.join("config", "event_templates") }

    before do
      roles(:admin)
      sign_in(admin)
    end

    context "when an event template exists" do
      around do |example|
        template_file = template_dir.join("hoeck.yml")
        template_file.write({"label" => "Höck"}.to_yaml)
        example.run
      ensure
        template_file.delete if template_file.exist?
      end

      it "shows the new_from_template dropdown" do
        get group_events_path(group)
        expect(response.body).to include(new_from_template_group_events_path(group,
          event_template: "hoeck"))
        expect(response.body).to include("Höck")
      end

      it "does not show the dropdown on the courses tab" do
        get group_events_path(group, type: "Event::Course")
        expect(response.body).not_to include("new_from_template")
      end

      it "does not offer underscore-prefixed templates" do
        get group_events_path(group)
        expect(response.body).not_to include(new_from_template_group_events_path(group,
          event_template: "_example"))
      end
    end

    context "when no event template exists" do
      before do
        # Stub on the prepended module, not on EventsController: a prepended
        # method wins over one defined on the class, so any_instance_of on the
        # controller would not intercept it.
        allow_any_instance_of(Bienenschweiz::EventsController)
          .to receive(:event_templates).and_return({})
      end

      it "does not show the new_from_template dropdown" do
        get group_events_path(group)
        expect(response.body).not_to include("new_from_template")
      end
    end
  end

  describe "GET #new_from_template" do
    let(:template_dir) { HitobitoBienenschweiz::Wagon.root.join("config", "event_templates") }
    let(:template_data) do
      {
        "label" => "Höck",
        "description" => "Prefilled event description",
        "location" => "Prefilled event location",
        "required_contact_attrs" => ["phone_numbers"],
        "hidden_contact_attrs" => ["nickname"],
        "application_questions" => [{"question" => "Kommst du zum Apéro?", "required" => false}],
        "admin_questions" => [{"question" => "Anmeldung geprüft?", "required" => false}]
      }
    end

    around do |example|
      template_file = template_dir.join("hoeck.yml")
      template_file.write(template_data.to_yaml)
      example.run
    ensure
      template_file.delete if template_file.exist?
    end

    context "as admin with create permission" do
      before do
        roles(:admin)
        sign_in(admin)
      end

      it "renders the new event form" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(response).to have_http_status(:ok)
      end

      it "builds a plain event, not a course" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(assigns(:event)).to be_an_instance_of(Event)
        expect(assigns(:event).groups).to eq([group])
      end

      it "does not use the label as an event attribute" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(response.body).not_to include(">Höck<")
      end

      it "prefills description from template" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(response.body).to include("Prefilled event description")
      end

      it "prefills location from template" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(response.body).to include("Prefilled event location")
      end

      it "prefills application questions from template" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(response.body).to include("Kommst du zum Apéro?")
      end

      it "prefills admin questions from template" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(response.body).to include("Anmeldung geprüft?")
      end

      it "marks required_contact_attrs as required" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(response.body).to include(
          'id="event_contact_attrs_phone_numbers_required" value="required" checked="checked"'
        )
      end

      it "marks hidden_contact_attrs as hidden" do
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(response.body).to include(
          'id="event_contact_attrs_nickname_hidden" value="hidden" checked="checked"'
        )
      end

      it "raises RecordNotFound for an unknown template" do
        expect do
          get new_from_template_group_events_path(group, event_template: "does-not-exist")
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "raises RecordNotFound for an underscore-prefixed template" do
        expect do
          get new_from_template_group_events_path(group, event_template: "_example")
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "as person without create permission" do
      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect do
          get new_from_template_group_events_path(group, event_template: "hoeck")
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

    context "for a non-course event" do
      let(:event) { Fabricate(:event, groups: [group]) }

      before do
        roles(:admin)
        sign_in(admin)
      end

      it "does not show the Kursunterlagen tab" do
        get group_event_path(group, event)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(group_event_course_materials_path(group, event))
      end

      it "redirects with an error message" do
        get group_event_course_materials_path(group, event)

        expect(response).to redirect_to(group_event_path(group, event))
        expect(flash[:alert]).to eq("Kursunterlagen gibt es nur für Kurse.")
      end

      it "still raises CanCan::AccessDenied without update permission" do
        sign_in(other_person)

        expect do
          get group_event_course_materials_path(group, event)
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe "event question relevance" do
    let!(:application_question) do
      Fabricate(:event_question, event: course, question: "App-Frage?", admin: false)
    end
    let!(:admin_question) do
      Fabricate(:event_question, event: course, question: "Admin-Frage?", admin: true)
    end

    before do
      roles(:admin)
      sign_in(admin)
    end

    it "renders a relevance dropdown for application and admin questions" do
      get edit_group_event_path(group, course)

      expect(response.body).to include(
        %(name="event[application_questions_attributes][0][relevance]")
      )
      expect(response.body).to include(
        %(name="event[admin_questions_attributes][0][relevance]")
      )
    end

    it "persists the chosen relevance for an application question" do
      patch group_event_path(group, course), params: {
        event: {
          application_questions_attributes: {
            "0" => {id: application_question.id, relevance: "leaders"}
          }
        }
      }

      expect(application_question.reload.relevance).to eq("leaders")
    end

    it "persists the chosen relevance for an admin question" do
      patch group_event_path(group, course), params: {
        event: {
          admin_questions_attributes: {
            "0" => {id: admin_question.id, relevance: "participants"}
          }
        }
      }

      expect(admin_question.reload.relevance).to eq("participants")
    end
  end
end
