# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe FeedbackReportsController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:other_sektion) { groups(:aargauisches_seetal) }
  let(:kind_a) { Fabricate(:event_kind) }
  let(:kind_b) { Fabricate(:event_kind) }
  let(:admin) { people(:admin) }

  let(:course) do
    Fabricate(:course, name: "Fachperson Bildung Grundkurs", kind: kind_a, groups: [sektion])
  end
  let(:other_course) do
    Fabricate(:course, name: "Anderer Kurs", kind: kind_b, groups: [other_sektion])
  end

  let(:wide_date_range) { {since: "2000-01-01", until: Date.tomorrow.to_s} }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "#index" do
    it "renders successfully for an admin" do
      get feedback_reports_path
      expect(response).to have_http_status(:ok)
    end

    it "shows the Kurse main nav section as active, with the report nested in its left nav" do
      get feedback_reports_path

      expect(response.body).to match(/<li class="nav-left-section active">.*Kurse.*<\/li>/m)
      expect(response.body).to include(%(<a href="#{feedback_reports_path}">Feedback-Bericht</a>))
    end

    it "ties the export button to the filter form via formaction, not a static link" do
      # A plain link with a fixed href would ignore filter changes made client-side
      # until "Suchen" is clicked; submitting the live form on click always exports
      # whatever is currently selected.
      get feedback_reports_path

      expect(response.body).to match(
        /<button[^>]*form=["']feedback-report-filter["']/
      )
      expect(response.body).to match(
        /<button[^>]*formaction=["']#{export_feedback_reports_path}["']/
      )
    end

    it "disables Turbo on the export button so the xlsx response triggers a real download" do
      # Turbo intercepts form submissions by default and tries to process the
      # response as a page visit/Turbo Stream; a binary xlsx response breaks
      # that (no download happens, and it can leave Stimulus controllers like
      # tom-select in a broken "already initialized" state on re-render).
      # data-turbo="false" on the submitter makes Turbo skip interception for
      # this button specifically, so the browser handles it as a plain
      # navigation and honors the attachment's Content-Disposition.
      get feedback_reports_path

      expect(response.body).to match(/<button[^>]*data-turbo=["']false["']/)
    end

    it "shows the same left nav (including the report link) on the course list itself" do
      get list_courses_path

      expect(response.body).to match(/<li class="nav-left-section active">.*Kurse.*<\/li>/m)
      expect(response.body).to include(%(<a href="#{feedback_reports_path}">Feedback-Bericht</a>))
    end

    context "as a person with layer_and_below_full but not the admin permission" do
      let(:sektion_admin) do
        Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: groups(:sektion_admin_381)).person
      end

      before { sign_in(sektion_admin) }

      it "raises access denied" do
        expect { get feedback_reports_path }.to raise_error(CanCan::AccessDenied)
      end
    end

    context "as an unrelated person" do
      before { sign_in(Fabricate(:person)) }

      it "raises access denied" do
        expect { get feedback_reports_path }.to raise_error(CanCan::AccessDenied)
      end
    end

    it "only shows courses matching the group filter" do
      Fabricate(:feedback_round, event: course, kind: "final")
      Fabricate(:feedback_round, event: other_course, kind: "final")

      get feedback_reports_path,
        params: {filters: {groups: {ids: [sektion.id]}, date_range: wide_date_range}}

      expect(response.body).to include(course.name)
      expect(response.body).not_to include(other_course.name)
    end

    it "only shows courses matching the course kind filter" do
      Fabricate(:feedback_round, event: course, kind: "final")
      Fabricate(:feedback_round, event: other_course, kind: "final")

      get feedback_reports_path,
        params: {filters: {course_kind: {id: [kind_a.id]}, date_range: wide_date_range}}

      expect(response.body).to include(course.name)
      expect(response.body).not_to include(other_course.name)
    end

    it "does not include courses whose feedback is only an intermediate round" do
      Fabricate(:feedback_round, event: course, kind: "intermediate")

      get feedback_reports_path, params: {filters: {date_range: wide_date_range}}

      expect(response.body).not_to include(course.name)
    end
  end

  describe "#export" do
    it "sends an xlsx file" do
      Fabricate(:feedback_round, event: course, kind: "final")

      get export_feedback_reports_path, params: {filters: {date_range: wide_date_range}}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xlsx")
      expect(response.headers["Content-Disposition"]).to include(".xlsx")
      expect(response.body).to start_with("PK") # xlsx files are zip archives
    end

    it "only includes rounds for courses matching the group filter" do
      matching_round = Fabricate(:feedback_round, event: course, kind: "final")
      Fabricate(:feedback_round, event: other_course, kind: "final")

      allow(Export::Tabular::FeedbackReports::Result).to receive(:xlsx).and_return("")

      get export_feedback_reports_path,
        params: {filters: {groups: {ids: [sektion.id]}, date_range: wide_date_range}}

      expect(Export::Tabular::FeedbackReports::Result).to have_received(:xlsx) do |rounds, _ability|
        expect(rounds.pluck(:id)).to eq([matching_round.id])
      end
    end

    it "does not include rounds whose feedback is only an intermediate round" do
      Fabricate(:feedback_round, event: course, kind: "intermediate")

      allow(Export::Tabular::FeedbackReports::Result).to receive(:xlsx).and_return("")

      get export_feedback_reports_path, params: {filters: {date_range: wide_date_range}}

      expect(Export::Tabular::FeedbackReports::Result).to have_received(:xlsx) do |rounds, _ability|
        expect(rounds).to be_empty
      end
    end

    context "as a person with layer_and_below_full but not the admin permission" do
      let(:sektion_admin) do
        Fabricate(Group::SektionAdministrator::AdminSektion.sti_name.to_sym,
          group: groups(:sektion_admin_381)).person
      end

      before { sign_in(sektion_admin) }

      it "raises access denied" do
        expect { get export_feedback_reports_path }.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
