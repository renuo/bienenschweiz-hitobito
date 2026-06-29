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
