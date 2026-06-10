# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  class Checklist
    class Section < Export::Pdf::Section
      CHECKBOX_SIZE = 7

      alias_method :qcontrol, :model

      private

      def person
        qcontrol.person
      end

      def inspector
        qcontrol.inspector
      end

      def group
        qcontrol.group
      end

      def t(key, **opts)
        I18n.t("checklist.#{key}", **opts)
      end

      def l(date)
        date.present? ? I18n.l(date, format: :default) : ""
      end

      def title(content)
        text(content, style: :bold)
        pdf.move_down(4)
      end

      def separator
        pdf.move_down(6)
        with_line_width(0.3) do
          pdf.stroke { pdf.horizontal_rule }
        end
        pdf.move_down(6)
      end

      # Draws a checkbox at the given position. The bundled fonts contain no
      # ballot box glyphs (U+2610/U+2611), so the box and check mark are drawn
      # with graphics primitives.
      def checkbox(x, y, checked, size: CHECKBOX_SIZE)
        with_line_width(0.75) do
          pdf.stroke do
            pdf.rectangle([x, y], size, size)
            check_mark(x, y, size) if checked
          end
        end
      end

      def check_mark(x, y, size)
        pdf.line([x + (0.2 * size), y - (0.55 * size)],
          [x + (0.4 * size), y - (0.8 * size)])
        pdf.line([x + (0.4 * size), y - (0.8 * size)],
          [x + (0.85 * size), y - (0.2 * size)])
      end

      def with_line_width(width)
        previous = pdf.line_width
        pdf.line_width = width
        yield
      ensure
        pdf.line_width = previous
      end

      # Lays out checkbox/label pairs in equally wide columns on one line.
      # items: array of [label, checked] pairs.
      def checkbox_row(items)
        column_width = bounds.width / items.size
        top = cursor
        heights = items.each_with_index.map do |(label, checked), index|
          checkbox_item(label, checked, index * column_width, top, column_width)
        end
        pdf.move_down(heights.max + 4)
      end

      def checkbox_item(label, checked, x, top, column_width, label_offset: 11)
        checkbox(x, top - 1, checked)
        label_width = column_width - label_offset - 4
        text_box(label, at: [x + label_offset, top], width: label_width)
        pdf.height_of(label, width: label_width)
      end
    end
  end
end
