# frozen_string_literal: true

# Copyright (c) 2012-2026, BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

# Hand-rolled inline SVG chart builders for the feedback report.
#
# These intentionally avoid any JS charting library: the app's global print
# stylesheet (print.scss.erb) forces `background-color`/`color` to be reset
# via `!important` on every element, which would silently blank out a
# CSS-colored chart when printed (as already happens to the one CSS
# progress-bar "chart" that exists elsewhere in the app). SVG shapes are
# colored via the `fill` attribute, which that stylesheet never touches, so
# these charts render identically on screen and in a browser's print-to-PDF.
module FeedbackReportsHelper
  RATING_BAR_COLOR = "#3d6ea5"
  PIE_EMPTY_COLOR = "#d9d9d9"
  YES_COLOR = "#2e7d32"
  NO_COLOR = "#c62828"

  BarGeometry = Struct.new(:max_count, :label_height, :bar_area_height, :bar_width, :slot_width,
    :height, keyword_init: true)

  # segments for svg_pie_chart, built here rather than inline in the view so
  # a multi-line array literal doesn't run into Haml's line-continuation rules.
  def yes_no_pie_segments(counts)
    [
      [t("feedback_reports.report.yes"), counts[true], YES_COLOR],
      [t("feedback_reports.report.no"), counts[false], NO_COLOR]
    ]
  end

  # segments: Array of [label, count, color]
  def svg_pie_chart(segments, size: 160)
    total = segments.sum { |_label, count, _color| count }

    content_tag(:div, class: "feedback-report-chart feedback-report-chart--pie") do
      safe_join([pie_svg(segments, total, size), pie_legend(segments, total)])
    end
  end

  # counts: Hash{1..5 => count}
  def svg_bar_chart(counts, width: 260, height: 160, bar_color: RATING_BAR_COLOR)
    values = counts.keys.sort
    geometry = bar_geometry(values.size, counts.values, width, height)

    content_tag(:div, class: "feedback-report-chart feedback-report-chart--bar") do
      content_tag(:svg, width: width, height: height, viewBox: "0 0 #{width} #{height}") do
        safe_join(values.map.with_index { |value, index|
          bar_group(value, counts[value].to_i, index, geometry, bar_color)
        })
      end
    end
  end

  private

  def pie_svg(segments, total, size)
    radius = size / 2.0
    center = radius

    content_tag(:svg, width: size, height: size, viewBox: "0 0 #{size} #{size}") do
      if total.zero?
        content_tag(:circle, "", cx: center, cy: center, r: radius - 1, fill: PIE_EMPTY_COLOR)
      else
        safe_join(pie_slice_paths(segments, total, center, radius))
      end
    end
  end

  def pie_slice_paths(segments, total, center, radius)
    angle = -Math::PI / 2 # start at 12 o'clock
    segments.filter_map do |_label, count, color|
      next if count.zero?

      fraction = count.to_f / total
      if fraction >= 1
        next content_tag(:circle, "", cx: center, cy: center, r: radius - 1, fill: color)
      end

      start_angle = angle
      angle += fraction * 2 * Math::PI
      content_tag(:path, "", d: pie_slice_path(center, radius, start_angle, angle), fill: color)
    end
  end

  def pie_slice_path(center, radius, start_angle, end_angle)
    start_point = polar_point(center, radius, start_angle)
    end_point = polar_point(center, radius, end_angle)
    large_arc = ((end_angle - start_angle) > Math::PI) ? 1 : 0

    [
      "M #{center} #{center}",
      "L #{start_point.join(" ")}",
      "A #{radius} #{radius} 0 #{large_arc} 1 #{end_point.join(" ")}",
      "Z"
    ].join(" ")
  end

  def polar_point(center, radius, angle)
    [(center + radius * Math.cos(angle)).round(2), (center + radius * Math.sin(angle)).round(2)]
  end

  def pie_legend(segments, total)
    content_tag(:ul, class: "feedback-report-chart__legend") do
      safe_join(segments.map { |label, count, color| pie_legend_item(label, count, color, total) })
    end
  end

  def pie_legend_item(label, count, color, total)
    percentage = total.zero? ? 0 : (count.to_f / total * 100).round
    content_tag(:li) do
      safe_join([pie_legend_swatch(color), " #{label}: #{count} (#{percentage}%)"])
    end
  end

  def pie_legend_swatch(color)
    content_tag(:svg, width: 12, height: 12, class: "feedback-report-chart__swatch") do
      content_tag(:rect, "", width: 12, height: 12, fill: color)
    end
  end

  def bar_geometry(count, values, width, height)
    axis_height = 20
    label_height = 16 # reserved so the value label above the tallest bar isn't clipped

    BarGeometry.new(
      max_count: [values.max.to_i, 1].max,
      label_height: label_height,
      bar_area_height: height - axis_height - label_height,
      bar_width: width.to_f / count * 0.6,
      slot_width: width.to_f / count,
      height: height
    )
  end

  def bar_position(count, index, geometry)
    bar_height = (count.to_f / geometry.max_count) * geometry.bar_area_height
    x = index * geometry.slot_width + (geometry.slot_width - geometry.bar_width) / 2.0
    y = geometry.label_height + (geometry.bar_area_height - bar_height)
    [x, y, bar_height]
  end

  def bar_group(value, count, index, geometry, bar_color)
    x, y, bar_height = bar_position(count, index, geometry)

    safe_join([
      bar_rect(x, y, bar_height, geometry.bar_width, bar_color),
      bar_text(count, x, y - 4, geometry.bar_width, "feedback-report-chart__value"),
      bar_text(value, x, geometry.height - 4, geometry.bar_width,
        "feedback-report-chart__axis-label")
    ])
  end

  def bar_rect(x, y, bar_height, bar_width, bar_color)
    content_tag(:rect, "", x: x, y: y, width: bar_width, height: [bar_height, 0].max,
      fill: bar_color)
  end

  def bar_text(text, x, y, bar_width, css_class)
    content_tag(:text, text, x: x + bar_width / 2.0, y: y, "text-anchor": "middle",
      class: css_class)
  end
end
