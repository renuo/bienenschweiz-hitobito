# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe FeedbackRoundsController, type: :request do
  let(:sektion) { groups(:aarau_und_umgebung) }
  let(:admin) { people(:admin) }
  let(:event) { Fabricate(:course, kind: Fabricate(:event_kind), groups: [sektion]) }
  let(:participant) { Fabricate(:person) }

  before do
    roles(:admin)
    sign_in(admin)
    participation = Fabricate(:event_participation, event:, active: true, participant:)
    Fabricate(Event::Course::Role::Participant.sti_name.to_sym, participation:)
  end

  let!(:round) { Fabricate(:feedback_round, event:) }

  describe "#show" do
    it "renders successfully" do
      get group_event_feedback_round_path(sektion, event, round)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(participant.full_name)
    end

    it "shows the Feedback tab as active, nested under the course" do
      get group_event_feedback_round_path(sektion, event, round)
      expect(response.body).to match(/<li class="active"[^>]*>.*Feedback.*<\/li>/m)
    end
  end

  describe "#index" do
    it "shows the Feedback tab as active" do
      get group_event_feedback_rounds_path(sektion, event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<li class="active"[^>]*>.*Feedback.*<\/li>/m)
    end
  end

  describe "#new" do
    it "shows the Feedback tab as active" do
      get new_group_event_feedback_round_path(sektion, event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<li class="active"[^>]*>.*Feedback.*<\/li>/m)
    end
  end
end
