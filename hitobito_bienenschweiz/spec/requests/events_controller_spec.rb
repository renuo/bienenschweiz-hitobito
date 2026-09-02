# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe EventsController, type: :request do
  # The specs run against the templates that actually ship in the wagon rather
  # than writing throw-away YAML files. Kind templates are keyed by Event::Kind
  # id, so the kind under test is fabricated with the id of a shipped template.
  let(:template_kind_id) { 4 }
  let(:template_slug) { "vorlage-anlass" }
  let(:kind_template) { load_template("event_kind_templates", template_kind_id) }
  let(:event_template) { load_template("event_templates", template_slug) }

  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }
  let(:other_person) { Fabricate(:person) }
  let(:kind) { Fabricate(:event_kind) }
  let(:course) do
    Fabricate(:course, kind: kind, groups: [group],
      delivery_address: "Musterstrasse 1\n3000 Bern",
      billing_address: "Buchhaltung AG\n8000 Zürich")
  end

  def load_template(dir, key)
    YAML.safe_load_file(HitobitoBienenschweiz::Wagon.root.join("config", dir, "#{key}.yml"))
  end

  describe "GET #index (courses)" do
    context "as admin with create permission" do
      before do
        roles(:admin)
        sign_in(admin)
      end

      context "when a kind has a template file" do
        let!(:kind) { Fabricate(:event_kind, id: template_kind_id) }

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

      # Uses config/event_kind_templates/4.yml ("Basiskurs Imkern")
      context "with a template file for the kind" do
        let(:kind) { Fabricate(:event_kind, id: template_kind_id) }

        it "prefills description from template" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include(kind_template["description"].lines.first.strip)
        end

        it "prefills motto from template" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include(kind_template["motto"])
        end

        it "prefills application questions from template" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include(
            CGI.escapeHTML(kind_template["application_questions"].first["question"].strip)
          )
        end

        it "prefills admin questions from template" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          expect(response.body).to include(
            CGI.escapeHTML(kind_template["admin_questions"].last["question"].strip)
          )
        end

        it "marks required_contact_attrs as required" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          kind_template["required_contact_attrs"].each do |attr|
            expect(response.body).to include(
              %(id="event_contact_attrs_#{attr}_required" value="required" checked="checked")
            )
          end
        end

        it "marks hidden_contact_attrs as hidden" do
          get new_from_kind_group_events_path(group, event_kind_id: kind.id)
          kind_template["hidden_contact_attrs"].each do |attr|
            expect(response.body).to include(
              %(id="event_contact_attrs_#{attr}_hidden" value="hidden" checked="checked")
            )
          end
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
    before do
      roles(:admin)
      sign_in(admin)
    end

    context "with the templates shipped in config/event_templates" do
      it "shows the new_from_template dropdown" do
        get group_events_path(group)
        expect(response.body).to include(new_from_template_group_events_path(group,
          event_template: template_slug))
        expect(response.body).to include(event_template["label"])
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

  # config/event_templates/vorlage-anlass.yml
  describe "GET #new_from_template" do
    context "as admin with create permission" do
      before do
        roles(:admin)
        sign_in(admin)
      end

      it "renders the new event form" do
        get new_from_template_group_events_path(group, event_template: template_slug)
        expect(response).to have_http_status(:ok)
      end

      it "builds a plain event, not a course" do
        get new_from_template_group_events_path(group, event_template: template_slug)
        expect(assigns(:event)).to be_an_instance_of(Event)
        expect(assigns(:event).groups).to eq([group])
      end

      it "does not use the label as an event attribute" do
        get new_from_template_group_events_path(group, event_template: template_slug)
        expect(assigns(:event).attributes).not_to include("label")
        expect(response.body).not_to include(">#{event_template["label"]}<")
      end

      it "prefills the event attributes from the template" do
        get new_from_template_group_events_path(group, event_template: template_slug)
        expect(assigns(:event)).to have_attributes(
          external_applications: event_template["external_applications"],
          applications_cancelable: event_template["applications_cancelable"],
          globally_visible: event_template["globally_visible"],
          export_to_website: event_template["export_to_website"]
        )
      end

      it "marks required_contact_attrs as required" do
        get new_from_template_group_events_path(group, event_template: template_slug)
        event_template["required_contact_attrs"].each do |attr|
          expect(response.body).to include(
            %(id="event_contact_attrs_#{attr}_required" value="required" checked="checked")
          )
        end
      end

      it "marks hidden_contact_attrs as hidden" do
        get new_from_template_group_events_path(group, event_template: template_slug)
        event_template["hidden_contact_attrs"].each do |attr|
          expect(response.body).to include(
            %(id="event_contact_attrs_#{attr}_hidden" value="hidden" checked="checked")
          )
        end
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
          get new_from_template_group_events_path(group, event_template: template_slug)
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
