# frozen_string_literal: true

#  Copyright (c) 2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe SupervisionsController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:admin) { people(:admin) }

  let(:person) { Fabricate(:person) }
  let(:supervisor) { Fabricate(:person) }
  let(:course_type) { event_kinds(:dummy) }

  before do
    roles(:admin)
    sign_in(admin)
    Fabricate(:role, person: supervisor, group: groups(:themenbezogene_kontakte),
      type: Group::ThemenbezogeneKontakte::Supervisor.sti_name)
  end

  describe "#index" do
    let!(:supervisions) {
      [
        Fabricate(:supervision, person: person, supervisor: supervisor,
          check_date: Date.new(2023, 1, 1), kind: "supervision", result: "fulfilled",
          course_type: course_type),
        Fabricate(:supervision, person: person, supervisor: supervisor,
          check_date: Date.new(2023, 2, 1), kind: "feedback", result: "good",
          course_type: course_type)
      ]
    }

    it "shows the supervisions with their labels" do
      get group_person_supervisions_path(sektion, person)
      expect(response).to have_http_status(:ok)
      supervisions.each do |supervision|
        expect(response.body).to include(supervision.check_date.strftime("%d.%m.%Y"))
      end
      expect(response.body).to include("Kursfeedback")
      expect(response.body).to include("vollständig erfüllt")
      expect(response.body).to include("gut bis sehr gut")
      expect(response.body).to include(course_type.label)
    end

    it "links the attached document" do
      supervisions.first.document.attach(
        io: Rails.root.join("spec", "fixtures", "files", "logo-icon.png").open,
        filename: "logo-icon.png", content_type: "image/png"
      )
      get group_person_supervisions_path(sektion, person)
      expect(response.body).to include("logo-icon.png")
    end
  end

  describe "#new" do
    it "renders the new supervision form" do
      get new_group_person_supervision_path(sektion, person)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Art der Supervision")
      expect(response.body).to include("Kurs / Tätigkeit")
      expect(response.body).to include(supervisor.full_name)
      expect(response.body).to include(course_type.to_s)
      expect(response.body).to include('data-controller="supervision-form"')
      expect(response.body).to include('data-supervision-form-target="kind"')
      expect(response.body).to include('data-supervision-form-target="result"')
      expect(response.body).to include('data-supervision-form-target="supervisor"')
      # results of the not selected kind are rendered hidden
      expect(response.body).to match(/<option data-kind="feedback" hidden="hidden"/)
      expect(response.body).not_to match(/<option data-kind="supervision" hidden/)
    end
  end

  describe "#create" do
    let(:supervision_params) do
      {
        check_date: Date.new(2023, 5, 1),
        supervisor_id: supervisor.id,
        kind: "supervision",
        course_type_id: course_type.id,
        result: "partially_fulfilled"
      }
    end

    it "creates a new supervision" do
      expect do
        post group_person_supervisions_path(sektion, person),
          params: {supervision: supervision_params}
      end.to change { Supervision.count }.by(1)

      supervision = Supervision.last
      expect(supervision.person).to eq(person)
      expect(supervision.author).to eq(admin)
      expect(supervision.supervisor).to eq(supervisor)
      expect(supervision.check_date).to eq(Date.new(2023, 5, 1))
      expect(supervision.kind).to eq("supervision")
      expect(supervision.course_type).to eq(course_type)
      expect(supervision.result).to eq("partially_fulfilled")
    end

    context "with a document" do
      let(:document) do
        Rack::Test::UploadedFile.new(Rails.root.join("spec", "fixtures", "files",
          "logo-icon.png"), "image/png")
      end

      it "attaches the document" do
        post group_person_supervisions_path(sektion, person),
          params: {supervision: supervision_params.merge(document: document)}

        supervision = Supervision.last
        expect(supervision.document).to be_attached
        expect(supervision.document.filename.to_s).to eq("logo-icon.png")
      end
    end

    context "when the supervisor has no supervisor role" do
      let(:supervision_params) do
        {
          check_date: Date.new(2023, 5, 1),
          supervisor_id: Fabricate(:person).id,
          kind: "supervision",
          course_type_id: course_type.id,
          result: "fulfilled"
        }
      end

      it "does not create a supervision" do
        expect do
          post group_person_supervisions_path(sektion, person),
            params: {supervision: supervision_params}
        end.not_to change { Supervision.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("muss eine Person mit aktiver Supervisor-Rolle sein")
      end
    end

    context "when the params are invalid" do
      let(:supervision_params) do
        {
          check_date: nil, # invalid check date
          kind: "supervision",
          course_type_id: course_type.id,
          result: "fulfilled"
        }
      end

      it "does not create a supervision and renders the form with errors" do
        expect do
          post group_person_supervisions_path(sektion, person),
            params: {supervision: supervision_params}
        end.not_to change { Supervision.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Kontrolldatum muss ausgefüllt werden")
      end
    end
  end

  describe "#destroy" do
    let!(:supervision) {
      Fabricate(:supervision, person: person, supervisor: supervisor,
        check_date: Date.new(2023, 1, 1))
    }

    it "destroys the supervision" do
      expect do
        delete group_person_supervision_path(sektion, person, supervision)
      end.to change { Supervision.count }.by(-1)
    end
  end

  describe "authorization" do
    let!(:supervision) {
      Fabricate(:supervision, person: person, supervisor: supervisor,
        check_date: Date.new(2023, 1, 1))
    }

    context "as a person with supervisor role" do
      before { sign_in(supervisor) }

      it "grants access" do
        get group_person_supervisions_path(sektion, person)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as a person without admin or supervisor role" do
      before { sign_in(Fabricate(:person)) }

      it "denies access" do
        expect do
          get group_person_supervisions_path(sektion, person)
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
