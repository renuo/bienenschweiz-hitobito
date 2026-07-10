# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe "Event::ParticipationsController", type: :request do
  let(:kas_base_url) { "https://kas.example.com" }
  let(:admin) { people(:admin) }
  let(:other_person) { Fabricate(:person) }
  let(:kind) { Fabricate(:event_kind, kas_fixed_fee: true, kas_fee_code: "COURSE_FEE") }
  let(:course) { Fabricate(:course, kind: kind) }
  let(:group) { course.groups.first }

  def add_participant(person)
    participation = Fabricate(:event_participation, event: course, participant: person)
    Fabricate(course.participant_types.first.name.to_sym, participation: participation)
    participation
  end

  def stub_kas_success
    stub_request(:post, "#{kas_base_url}/api/v1/fees")
      .to_return(status: 201,
        body: {id: 1}.to_json,
        headers: {"Content-Type" => "application/json"})
  end

  before do
    allow(Settings.kas).to receive(:base_url).and_return(kas_base_url)
    allow(Settings.kas).to receive(:api_token).and_return("test-token")
  end

  describe "POST #create_kas_fees" do
    subject(:post_create_kas_fees) do
      post create_kas_fees_group_event_participations_path(group, course)
    end

    context "as admin with update permission" do
      before { sign_in(admin) }

      context "with participants" do
        let!(:participant1) { Fabricate(:person) }
        let!(:participant2) { Fabricate(:person) }

        before do
          add_participant(participant1)
          add_participant(participant2)
        end

        context "when KAS API succeeds for all" do
          before { stub_kas_success }

          it "redirects to the participations index" do
            post_create_kas_fees
            expect(response).to redirect_to(group_event_participations_path(group, course))
          end

          it "sets a success flash" do
            post_create_kas_fees
            expect(flash[:notice]).to include("2")
          end

          it "calls the KAS API once per participant" do
            post_create_kas_fees
            expect(WebMock).to have_requested(:post, "#{kas_base_url}/api/v1/fees").twice
          end

          it "sends person_id and group_id in fee params" do
            post_create_kas_fees
            expect(WebMock).to have_requested(:post, "#{kas_base_url}/api/v1/fees")
              .with { |req|
                body = JSON.parse(req.body)["fee"]
                body["person_id"] == participant1.id && body["group_id"] == group.id
              }
          end

          it "marks kas_fees_created on the event" do
            expect { post_create_kas_fees }.to change { course.reload.kas_fees_created }.to(true)
          end
        end

        context "when kas_fees_created is already true" do
          before { course.update_column(:kas_fees_created, true) }

          it "redirects with an alert and does not call the KAS API" do
            post_create_kas_fees
            expect(response).to redirect_to(group_event_participations_path(group, course))
            expect(flash[:alert]).to be_present
            expect(WebMock).not_to have_requested(:post, "#{kas_base_url}/api/v1/fees")
          end
        end

        context "when kas_fixed_fee is false on the kind" do
          before { kind.update_column(:kas_fixed_fee, false) }

          it "redirects with an alert and does not call the KAS API" do
            post_create_kas_fees
            expect(response).to redirect_to(group_event_participations_path(group, course))
            expect(flash[:alert]).to be_present
            expect(WebMock).not_to have_requested(:post, "#{kas_base_url}/api/v1/fees")
          end
        end

        context "when kas_fee_code is blank on the kind" do
          before { kind.update_column(:kas_fee_code, nil) }

          it "redirects with an alert and does not call the KAS API" do
            post_create_kas_fees
            expect(response).to redirect_to(group_event_participations_path(group, course))
            expect(flash[:alert]).to be_present
            expect(WebMock).not_to have_requested(:post, "#{kas_base_url}/api/v1/fees")
          end
        end

        context "when KAS API fails for one participant" do
          before do
            stub_request(:post, "#{kas_base_url}/api/v1/fees")
              .to_return(
                {status: 201, body: {id: 1}.to_json,
                 headers: {"Content-Type" => "application/json"}},
                {status: 422, body: {error: "invalid"}.to_json,
                 headers: {"Content-Type" => "application/json"}}
              )
          end

          it "redirects to the participations index" do
            post_create_kas_fees
            expect(response).to redirect_to(group_event_participations_path(group, course))
          end

          it "sets an alert flash" do
            post_create_kas_fees
            expect(flash[:alert]).to be_present
          end

          it "sets a warning flash with the failed participant's name" do
            post_create_kas_fees
            expect(flash[:warning]).to include(participant2.full_name)
          end

          it "still marks kas_fees_created because at least one succeeded" do
            expect { post_create_kas_fees }.to change { course.reload.kas_fees_created }.to(true)
          end
        end
      end

      context "with no participants" do
        before { stub_kas_success }

        it "redirects to the participations index" do
          post_create_kas_fees
          expect(response).to redirect_to(group_event_participations_path(group, course))
        end

        it "sets a success flash mentioning 0 fees" do
          post_create_kas_fees
          expect(flash[:notice]).to include("0")
        end

        it "does not call the KAS API" do
          post_create_kas_fees
          expect(WebMock).not_to have_requested(:post, "#{kas_base_url}/api/v1/fees")
        end
      end

      context "with participants who do not meet preconditions" do
        let!(:eligible_person) { Fabricate(:person) }
        let!(:ineligible_person) { Fabricate(:person) }

        before do
          add_participant(eligible_person)
          add_participant(ineligible_person)
          allow(Event::PreconditionChecker).to receive(:new)
            .with(anything, eligible_person).and_return(double(valid?: true))
          allow(Event::PreconditionChecker).to receive(:new)
            .with(anything, ineligible_person).and_return(double(valid?: false))
          stub_kas_success
        end

        it "only calls the KAS API for eligible participants" do
          post_create_kas_fees
          expect(WebMock).to have_requested(:post, "#{kas_base_url}/api/v1/fees").once
        end

        it "sets a success flash with the eligible count" do
          post_create_kas_fees
          expect(flash[:notice]).to include("1")
        end
      end

      context "with a leader but no participants" do
        before do
          participation = Fabricate(:event_participation, event: course,
            participant: Fabricate(:person))
          Fabricate(:"Event::Role::Leader", participation: participation)
          stub_kas_success
        end

        it "does not call the KAS API for the leader" do
          post_create_kas_fees
          expect(WebMock).not_to have_requested(:post, "#{kas_base_url}/api/v1/fees")
        end
      end
    end

    context "as person without update permission" do
      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect { post_create_kas_fees }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe "GET #new_kas_instructor_fees" do
    let(:instructor_kind) {
      Fabricate(:event_kind, kas_instructor_fees: true, kas_fee_code: "INST_FEE")
    }
    let(:instructor_course) do
      Fabricate(:course, kind: instructor_kind,
        dates: [Event::Date.new(start_at: Time.zone.today.beginning_of_year, label: "Hauptanlass")])
    end
    let(:instructor_group) { instructor_course.groups.first }

    def add_leader(person)
      participation = Fabricate(:event_participation, event: instructor_course, participant: person)
      Fabricate(:"Event::Role::Leader", participation: participation)
      participation
    end

    subject(:get_new_kas_instructor_fees) do
      get new_kas_instructor_fees_group_event_participations_path(instructor_group,
        instructor_course)
    end

    context "as admin" do
      before { sign_in(admin) }

      context "with a leader" do
        let!(:leader) { Fabricate(:person) }

        before { add_leader(leader) }

        it "returns 200" do
          get_new_kas_instructor_fees
          expect(response).to have_http_status(:ok)
        end

        it "shows the leader's name in the response body" do
          get_new_kas_instructor_fees
          expect(response.body).to include(leader.full_name)
        end

        it "shows the current year as a column" do
          get_new_kas_instructor_fees
          expect(response.body).to include(Time.zone.today.year.to_s)
        end

        it "shows the leader role label next to the name" do
          get_new_kas_instructor_fees
          expect(response.body).to include(leader.full_name)
          expect(response.body).to include(Event::Role::Leader.label)
        end

        context "with an assistant leader" do
          let!(:assistant_leader) { Fabricate(:person) }

          before do
            participation = Fabricate(:event_participation, event: instructor_course,
              participant: assistant_leader)
            Fabricate(:"Event::Role::AssistantLeader", participation: participation)
          end

          it "shows the assistant leader role label" do
            get_new_kas_instructor_fees
            expect(response.body).to include(assistant_leader.full_name)
            expect(response.body).to include(Event::Role::AssistantLeader.label)
          end
        end

        it "shows the participant count" do
          get_new_kas_instructor_fees
          expect(response.body).to include("0 Teilnehmende")
        end

        it "shows CHF 0.– budget when fewer than 6 participants" do
          get_new_kas_instructor_fees
          expect(response.body).to include("CHF 0.–")
        end

        context "with 8 participants" do
          before do
            8.times do
              p = Fabricate(:person)
              participation = Fabricate(:event_participation, event: instructor_course,
                participant: p)
              Fabricate(:"Event::Course::Role::Participant", participation: participation)
            end
          end

          it "shows CHF 275.– budget (6–12 tier)" do
            get_new_kas_instructor_fees
            expect(response.body).to include("CHF 275.–")
          end
        end
      end

      context "with dates spanning two years (start before July)" do
        before do
          Fabricate(:event_date, event: instructor_course,
            start_at: "2025-01-10", finish_at: "2026-12-15")
        end

        it "shows both years as columns" do
          get_new_kas_instructor_fees
          expect(response.body).to include("2025").and include("2026")
        end
      end

      context "with a start date on June 30th (boundary — included)" do
        before do
          Fabricate(:event_date, event: instructor_course,
            start_at: "2025-06-30", finish_at: "2026-04-30")
        end

        it "includes the start year" do
          get_new_kas_instructor_fees
          expect(response.body).to include("2025").and include("2026")
        end
      end

      context "with a start date after June 30th (excluded)" do
        before do
          Fabricate(:event_date, event: instructor_course,
            start_at: "2025-08-15", finish_at: "2026-04-30")
        end

        it "excludes the start year" do
          get_new_kas_instructor_fees
          expect(response.body).not_to include(">2025<")
          expect(response.body).to include("2026")
        end
      end

      context "with a start date after June 30th and no finish_at" do
        let(:instructor_course) do
          Fabricate(:course, kind: instructor_kind,
            dates: [Event::Date.new(start_at: Date.new(2025, 9, 1), label: "Hauptanlass")])
        end

        it "renders no year columns" do
          get_new_kas_instructor_fees
          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include(">2025<")
        end
      end

      context "when kas_instructor_fees is false" do
        before { instructor_kind.update_column(:kas_instructor_fees, false) }

        it "redirects with an alert" do
          get_new_kas_instructor_fees
          expect(response).to redirect_to(
            group_event_participations_path(instructor_group, instructor_course)
          )
          expect(flash[:alert]).to be_present
        end
      end

      context "when kas_fee_code is blank" do
        before { instructor_kind.update_column(:kas_fee_code, nil) }

        it "redirects with an alert" do
          get_new_kas_instructor_fees
          expect(response).to redirect_to(
            group_event_participations_path(instructor_group, instructor_course)
          )
          expect(flash[:alert]).to be_present
        end
      end
    end

    context "as person without update permission" do
      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect { get_new_kas_instructor_fees }.to raise_error(CanCan::AccessDenied)
      end
    end
  end

  describe "POST #create_kas_instructor_fees" do
    let(:instructor_kind) {
      Fabricate(:event_kind, kas_instructor_fees: true, kas_fee_code: "INST_FEE")
    }
    let(:instructor_course) { Fabricate(:course, kind: instructor_kind) }
    let(:instructor_group) { instructor_course.groups.first }

    def add_leader(person)
      participation = Fabricate(:event_participation, event: instructor_course, participant: person)
      Fabricate(:"Event::Role::Leader", participation: participation)
      participation
    end

    def post_instructor_fees(fees_params)
      post create_kas_instructor_fees_group_event_participations_path(
        instructor_group, instructor_course
      ),
        params: {fees: fees_params}
    end

    context "as admin" do
      before do
        sign_in(admin)
        stub_kas_success
      end

      context "with fees selected for a leader across two years" do
        let!(:leader) { Fabricate(:person) }

        before { add_leader(leader) }

        it "calls the KAS API once per non-zero person/year combination" do
          post_instructor_fees(leader.id.to_s => {"2025" => "150.00", "2026" => "125.00"})
          expect(WebMock).to have_requested(:post, "#{kas_base_url}/api/v1/fees").twice
        end

        it "sends the correct fee_type_code, group_id and total_amount" do
          post_instructor_fees(leader.id.to_s => {"2025" => "150.00"})
          expect(WebMock).to have_requested(:post, "#{kas_base_url}/api/v1/fees")
            .with { |req|
              body = JSON.parse(req.body)["fee"]
              body["fee_type_code"] == "INST_FEE" &&
                body["group_id"] == instructor_group.id &&
                body["total_amount"] == "150.00"
            }
        end

        it "skips years where the amount is zero" do
          post_instructor_fees(leader.id.to_s => {"2025" => "150.00", "2026" => "0"})
          expect(WebMock).to have_requested(:post, "#{kas_base_url}/api/v1/fees").once
        end

        it "skips years where the amount is blank" do
          post_instructor_fees(leader.id.to_s => {"2025" => "150.00", "2026" => ""})
          expect(WebMock).to have_requested(:post, "#{kas_base_url}/api/v1/fees").once
        end

        it "redirects to the participations index with a notice" do
          post_instructor_fees(leader.id.to_s => {"2025" => "150.00"})
          expect(response).to redirect_to(
            group_event_participations_path(instructor_group, instructor_course)
          )
          expect(flash[:notice]).to be_present
        end
      end

      context "with no fees param submitted" do
        it "does not call the KAS API" do
          post create_kas_instructor_fees_group_event_participations_path(instructor_group,
            instructor_course)
          expect(WebMock).not_to have_requested(:post, "#{kas_base_url}/api/v1/fees")
        end

        it "redirects with a notice" do
          post create_kas_instructor_fees_group_event_participations_path(instructor_group,
            instructor_course)
          expect(flash[:notice]).to be_present
        end
      end

      context "when the KAS API fails for one person/year" do
        let!(:leader) { Fabricate(:person) }

        before do
          add_leader(leader)
          stub_request(:post, "#{kas_base_url}/api/v1/fees")
            .to_return(
              {status: 422, body: {error: "invalid"}.to_json,
               headers: {"Content-Type" => "application/json"}}
            )
        end

        it "sets an alert flash containing the person name and API error" do
          post_instructor_fees(leader.id.to_s => {"2025" => "150.00"})
          expect(flash[:alert]).to include(leader.full_name)
          expect(flash[:alert]).to include("422")
        end

        it "does not set a success notice" do
          post_instructor_fees(leader.id.to_s => {"2025" => "150.00"})
          expect(flash[:notice]).not_to be_present
        end
      end

      context "when kas_instructor_fees is false" do
        before { instructor_kind.update_column(:kas_instructor_fees, false) }

        it "redirects with an alert and does not call the KAS API" do
          post create_kas_instructor_fees_group_event_participations_path(instructor_group,
            instructor_course)
          expect(response).to redirect_to(
            group_event_participations_path(instructor_group, instructor_course)
          )
          expect(flash[:alert]).to be_present
          expect(WebMock).not_to have_requested(:post, "#{kas_base_url}/api/v1/fees")
        end
      end

      context "when current year is already marked as created" do
        before do
          instructor_course.update_column(:kas_instructor_fees_created_years,
            [Time.zone.today.year])
        end

        it "redirects with an alert and does not call the KAS API" do
          post create_kas_instructor_fees_group_event_participations_path(instructor_group,
            instructor_course)
          expect(response).to redirect_to(
            group_event_participations_path(instructor_group, instructor_course)
          )
          expect(flash[:alert]).to be_present
          expect(WebMock).not_to have_requested(:post, "#{kas_base_url}/api/v1/fees")
        end
      end

      context "when fees are successfully created" do
        let!(:leader) { Fabricate(:person) }

        before { add_leader(leader) }

        it "marks the current year as created" do
          expect {
            post_instructor_fees(leader.id.to_s => {Time.zone.today.year.to_s => "150.00"})
          }.to change {
            instructor_course.reload.kas_instructor_fees_created_years
          }.to include(Time.zone.today.year)
        end
      end

      context "when all API calls fail" do
        let!(:leader) { Fabricate(:person) }

        before do
          add_leader(leader)
          stub_request(:post, "#{kas_base_url}/api/v1/fees")
            .to_return(status: 422, body: {error: "invalid"}.to_json,
              headers: {"Content-Type" => "application/json"})
        end

        it "does not mark the year as created" do
          post_instructor_fees(leader.id.to_s => {Time.zone.today.year.to_s => "150.00"})
          expect(instructor_course.reload.kas_instructor_fees_created_years)
            .not_to include(Time.zone.today.year)
        end
      end
    end

    context "as person without update permission" do
      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect {
          post create_kas_instructor_fees_group_event_participations_path(instructor_group,
            instructor_course)
        }.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
