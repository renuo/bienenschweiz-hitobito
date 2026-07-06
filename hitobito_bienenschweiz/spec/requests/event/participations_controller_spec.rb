# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe Event::ParticipationsController, type: :request do
  let(:kas_base_url) { "https://kas.example.com" }
  let(:admin) { people(:admin) }
  let(:other_person) { Fabricate(:person) }
  let(:kind) { Fabricate(:event_kind) }
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
end
