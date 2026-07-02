# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

RSpec.describe "Event::DiplomasController", type: :request do
  let(:group) { groups(:root) }
  let(:admin) { people(:admin) }
  let(:other_person) { Fabricate(:person) }
  let(:kind) { Fabricate(:event_kind) }
  let(:course) do
    Fabricate(:course, kind: kind, groups: [group],
      diploma_location: "Bern",
      diploma_issued_at: Date.new(2026, 6, 20))
  end

  describe "GET #show" do
    context "as AdministratorBienenSchweiz" do
      before do
        roles(:admin)
        sign_in(admin)
      end

      it "returns a PDF attachment" do
        get group_event_diploma_path(group, course)
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq("application/pdf")
        expect(response.headers["Content-Disposition"]).to include("attachment")
      end

      it "uses the event name in the filename" do
        get group_event_diploma_path(group, course)
        expect(response.headers["Content-Disposition"]).to include(".pdf")
      end
    end

    context "as person without edit permission" do
      before { sign_in(other_person) }

      it "raises CanCan::AccessDenied" do
        expect do
          get group_event_diploma_path(group, course)
        end.to raise_error(CanCan::AccessDenied)
      end
    end
  end
end
