# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

require "spec_helper"

RSpec.describe Event::KindCategoriesController, type: :request do
  let(:admin) { people(:admin) }

  before do
    roles(:admin)
    sign_in(admin)
  end

  describe "GET /event_kind_categories" do
    let!(:unrestricted) { Fabricate(:event_kind_category, label: "Offener Kurs") }
    let!(:restricted) {
      Fabricate(:event_kind_category, label: "Kantons-Kurs",
        layer_group_type: "Group::Kantonalverband")
    }

    before { get event_kind_categories_path }

    it { expect(response).to have_http_status(:ok) }

    it "shows the translated group type name for restricted categories" do
      expect(response.body).to include("Kantonalverband")
    end

    it "does not show the raw class name" do
      expect(response.body).not_to include("Group::Kantonalverband")
    end

    it "shows an empty cell for unrestricted categories" do
      expect(response.body).to include("Offener Kurs")
    end
  end

  describe "GET /event_kind_categories/:id" do
    context "with an unrestricted category" do
      let(:category) { Fabricate(:event_kind_category) }

      it "renders successfully" do
        get event_kind_category_path(category)
        expect(response).to have_http_status(:ok)
      end

      it "shows the label for layer_group_type with no value" do
        get event_kind_category_path(category)
        expect(response.body).to include(
          Event::KindCategory.human_attribute_name(:layer_group_type)
        )
      end
    end

    context "with a restricted category" do
      let(:category) { Fabricate(:event_kind_category, layer_group_type: "Group::Sektion") }

      it "shows the translated group type name" do
        get event_kind_category_path(category)
        expect(response.body).to include("Sektion")
      end

      it "does not show the raw class name" do
        get event_kind_category_path(category)
        expect(response.body).not_to include("Group::Sektion")
      end
    end
  end

  describe "GET /event_kind_categories/new" do
    before { get new_event_kind_category_path }

    it { expect(response).to have_http_status(:ok) }

    it "renders the select field for layer_group_type" do
      expect(response.body).to include('name="event_kind_category[layer_group_type]"')
    end

    it "includes all layer group types as options" do
      expect(response.body).to include("Dachverband")
      expect(response.body).to include("Kantonalverband")
      expect(response.body).to include("Sektion")
    end
  end

  describe "POST /event_kind_categories" do
    it "saves the layer_group_type when set" do
      post event_kind_categories_path, params: {
        event_kind_category: {label: "Sektions-Kurs", layer_group_type: "Group::Sektion"}
      }
      expect(Event::KindCategory.reorder(:id).last.layer_group_type).to eq("Group::Sektion")
    end

    it "saves nil when layer_group_type is blank" do
      post event_kind_categories_path, params: {
        event_kind_category: {label: "Offener Kurs", layer_group_type: ""}
      }
      expect(Event::KindCategory.reorder(:id).last.layer_group_type).to be_nil
    end
  end

  describe "GET /event_kind_categories/:id/edit" do
    let(:category) { Fabricate(:event_kind_category, layer_group_type: "Group::Kantonalverband") }

    before { get edit_event_kind_category_path(category) }

    it { expect(response).to have_http_status(:ok) }

    it "pre-selects the current layer_group_type" do
      expect(response.body).to match(
        %r{
          <option[^>]*selected[^>]*value="Group::Kantonalverband"|
          <option[^>]*value="Group::Kantonalverband"[^>]*selected
        }x
      )
    end

    it "shows the translated name of the pre-selected option" do
      expect(response.body).to include("Kantonalverband")
    end
  end

  describe "PATCH /event_kind_categories/:id" do
    let(:category) { Fabricate(:event_kind_category, layer_group_type: "Group::Sektion") }

    it "updates the layer_group_type" do
      patch event_kind_category_path(category), params: {
        event_kind_category: {layer_group_type: "Group::Dachverband"}
      }
      expect(category.reload.layer_group_type).to eq("Group::Dachverband")
    end

    it "clears the layer_group_type when blank is submitted" do
      patch event_kind_category_path(category), params: {
        event_kind_category: {layer_group_type: ""}
      }
      expect(category.reload.layer_group_type).to be_nil
    end
  end
end
