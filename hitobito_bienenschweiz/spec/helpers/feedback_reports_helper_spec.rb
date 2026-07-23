# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

require "spec_helper"

describe FeedbackReportsHelper, type: :helper do
  describe "#svg_pie_chart" do
    it "renders a single placeholder circle when there are no answers at all" do
      html = helper.svg_pie_chart([["Ja", 0, "#2e7d32"], ["Nein", 0, "#c62828"]])

      expect(html.scan("<circle").size).to eq(1)
      expect(html).not_to include("<path")
      expect(html).to include(FeedbackReportsHelper::PIE_EMPTY_COLOR)
    end

    it "renders a full circle (not an arc) when one segment has every answer" do
      html = helper.svg_pie_chart([["Ja", 2, "#2e7d32"], ["Nein", 0, "#c62828"]])

      expect(html.scan("<circle").size).to eq(1)
      expect(html).to include('fill="#2e7d32"')
      expect(html).not_to include("<path")
    end

    it "renders one arc path per non-empty segment for a mixed split" do
      html = helper.svg_pie_chart([["Ja", 2, "#2e7d32"], ["Nein", 1, "#c62828"]])

      expect(html.scan("<path").size).to eq(2)
      expect(html).not_to include("<circle")
    end

    it "includes a legend with counts and rounded percentages" do
      html = helper.svg_pie_chart([["Ja", 3, "#2e7d32"], ["Nein", 1, "#c62828"]])

      expect(html).to include("Ja: 3 (75%)")
      expect(html).to include("Nein: 1 (25%)")
    end

    it "shows 0% in the legend when there are no answers" do
      html = helper.svg_pie_chart([["Ja", 0, "#2e7d32"], ["Nein", 0, "#c62828"]])

      expect(html).to include("Ja: 0 (0%)")
      expect(html).to include("Nein: 0 (0%)")
    end
  end

  describe "#svg_bar_chart" do
    it "draws one bar per rating value" do
      html = helper.svg_bar_chart({1 => 0, 2 => 1, 3 => 0, 4 => 2, 5 => 1})

      expect(html.scan("<rect").size).to eq(5)
    end

    it "keeps the value label above the tallest bar within the viewBox" do
      html = helper.svg_bar_chart({1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 3})

      expect(html).to include('y="12.0"')
    end
  end

  describe "#yes_no_pie_segments" do
    it "builds Ja/Nein segments from a yes/no counts hash" do
      segments = helper.yes_no_pie_segments({true => 2, false => 1})

      expect(segments).to eq([
        [I18n.t("feedback_reports.report.yes"), 2, FeedbackReportsHelper::YES_COLOR],
        [I18n.t("feedback_reports.report.no"), 1, FeedbackReportsHelper::NO_COLOR]
      ])
    end
  end
end
