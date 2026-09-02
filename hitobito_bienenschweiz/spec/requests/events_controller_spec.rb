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

  describe "course-only form tabs" do
    let(:course_tab_labels) do
      [I18n.t("events.form_tabs.course_materials"), I18n.t("events.form_tabs.diploma")]
    end

    before do
      roles(:admin)
      sign_in(admin)
    end

    def rendered_tab_labels
      response.body.scan(/data-bs-toggle="tab"[^>]*>([^<]*)</).flatten.map(&:strip)
    end

    context "for a course" do
      it "shows them on the blank new form" do
        get new_group_event_path(group, event: {type: "Event::Course"})
        expect(rendered_tab_labels).to include(*course_tab_labels)
      end

      it "shows them on the new form built from a kind template" do
        get new_from_kind_group_events_path(group, event_kind_id: kind.id)
        expect(rendered_tab_labels).to include(*course_tab_labels)
      end

      it "shows them on the edit form" do
        get edit_group_event_path(group, course)
        expect(rendered_tab_labels).to include(*course_tab_labels)
      end

      it "renders the course material fields" do
        get edit_group_event_path(group, course)
        expect(response.body).to include("event_delivery_address")
        expect(response.body).to include("event_billing_address")
      end
    end

    context "for a plain event" do
      let(:event) { Fabricate(:event, groups: [group]) }

      it "hides them on the blank new form" do
        get new_group_event_path(group, event: {type: "Event"})
        expect(rendered_tab_labels).not_to include(*course_tab_labels)
      end

      it "hides them on the new form built from an event template" do
        template_file = HitobitoBienenschweiz::Wagon.root
          .join("config", "event_templates", "hoeck.yml")
        template_file.write({"label" => "Höck"}.to_yaml)
        get new_from_template_group_events_path(group, event_template: "hoeck")
        expect(rendered_tab_labels).not_to include(*course_tab_labels)
      ensure
        template_file.delete if template_file.exist?
      end

      it "hides them on the edit form" do
        get edit_group_event_path(group, event)
        expect(rendered_tab_labels).not_to include(*course_tab_labels)
      end

      it "does not render the course material fields" do
        get edit_group_event_path(group, event)
        expect(response.body).not_to include("event_delivery_address")
        expect(response.body).not_to include("event_billing_address")
      end
    end
  end

  describe "group selection (Durchgefuehrt von)" do
    let(:kv1) { groups(:aargauer_kantonalverband) }
    let(:kv2) { groups(:berner_kantonalverband) }
    let(:sektion) { groups(:aarau_und_umgebung) }
    let(:kv_admin) do
      admin_group = Group::KantonalverbandAdministrator.create!(name: "Admin", parent: kv1)
      person = Fabricate(:person)
      Fabricate(Group::KantonalverbandAdministrator::AdminKanton.name.to_sym,
        group: admin_group, person: person)
      person.reload
    end

    before { sign_in(kv_admin) }

    it "is offered on the plain event form" do
      get new_group_event_path(kv1, event: {type: "Event"})
      expect(response.body).to include("event_group_ids")
      expect(response.body).to include(I18n.t("event.run_by"))
    end

    it "is still offered on the course form" do
      get new_group_event_path(kv1, event: {type: "Event::Course"})
      expect(response.body).to include("event_group_ids")
    end

    it "persists several groups on a plain event" do
      post group_events_path(kv1), params: {event: {
        type: "Event", name: "Mehrgruppig", group_ids: [kv1.id, kv2.id],
        dates_attributes: {"0" => {start_at_date: Time.zone.today.to_s}}
      }}

      expect(Event.find_by(name: "Mehrgruppig").groups).to contain_exactly(kv1, kv2)
    end

    it "rejects groups of differing types" do
      event = Event.new(name: "Gemischt", groups: [kv1, sektion])
      event.dates.build(start_at: Time.zone.today)

      expect(event).not_to be_valid
      expect(event.errors[:group_ids]).to include(
        I18n.t("activerecord.errors.messages.must_have_same_type")
      )
    end

    it "lists a multi-group event only once from a common ancestor" do
      event = Event.new(name: "Mehrgruppig", groups: [kv1, kv2])
      event.dates.build(start_at: Time.zone.today)
      event.save!

      sign_in(people(:admin))
      get group_events_path(groups(:root))

      # groups(:root).self_and_descendants covers both groups, so the
      # joins(:groups) fan-out must not duplicate the event in the list.
      expect(response.body.scan(%r{/events/#{event.id}(?:\?|")}).size).to eq(1)
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
