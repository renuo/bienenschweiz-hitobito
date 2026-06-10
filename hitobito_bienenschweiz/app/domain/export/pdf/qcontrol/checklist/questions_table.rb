# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  class Checklist
    class QuestionsTable < Section
      HEADER_HEIGHT = 70
      POINT_WIDTH = 30
      TICK_WIDTH = 24
      DEADLINE_WIDTH = 50
      SECTION_BACKGROUND = "E6E6E6"
      # The bundled fonts contain no ballot glyphs (U+2717), so the
      # multiplication sign is used as tick mark instead.
      TICK = "×"

      def render
        return if answers.blank?

        pdf.move_down(16)
        table([header_row] + body_rows,
          header: true,
          width: bounds.width,
          column_widths: column_widths,
          cell_style: {border_width: 0.5, padding: [2, 3]}) do |t|
          t.row(0).height = HEADER_HEIGHT
        end
      end

      private

      def answers
        qcontrol.quality_control_answers
      end

      def header_row
        [
          vertical_cell(t("point")),
          {content: t("criterium"), font_style: :bold, valign: :bottom},
          vertical_cell(t("passed")),
          vertical_cell(t("partially_passed")),
          vertical_cell(t("not_passed")),
          {content: t("notes"), font_style: :bold, valign: :bottom},
          {content: t("deadline"), font_style: :bold, valign: :bottom}
        ]
      end

      def body_rows
        qcontrol.quality_control_sections.order(:number).flat_map do |section|
          [section_row(section)] + answers_of(section).map { |answer| answer_row(section, answer) }
        end
      end

      def answers_of(section)
        answers
          .includes(:quality_control_question)
          .of_section(section)
          .order("quality_control_questions.number")
      end

      def section_row(section)
        [
          {content: "#{section.number}.", font_style: :bold, align: :center,
           background_color: SECTION_BACKGROUND},
          {content: section.title, colspan: 6, font_style: :bold, align: :center,
           background_color: SECTION_BACKGROUND}
        ]
      end

      def answer_row(section, answer)
        question = answer.quality_control_question
        [
          {content: "#{section.number}.#{question.number}", font_style: :bold, align: :center},
          question_content(question),
          tick(answer.passed?),
          tick(answer.partially_passed?),
          tick(answer.not_passed?),
          answer.notes.to_s,
          l(answer.deadline_at)
        ]
      end

      def question_content(question)
        # descriptions contain literal backslash-n sequences (was gsub'd to <br/> in HTML)
        [question.title, question.description&.gsub('\n', "\n")].compact_blank.join("\n")
      end

      def tick(checked)
        {content: checked ? TICK : "", font_style: :bold, align: :center}
      end

      def vertical_cell(content)
        VerticalTextCell.new(pdf, [0, cursor], content: content)
      end

      def column_widths
        remainder = bounds.width - POINT_WIDTH - (3 * TICK_WIDTH) - DEADLINE_WIDTH
        criterium_width = remainder * 0.6
        notes_width = remainder * 0.4
        [POINT_WIDTH, criterium_width, TICK_WIDTH, TICK_WIDTH, TICK_WIDTH,
          notes_width, DEADLINE_WIDTH]
      end

      # Renders its content rotated by 90 degrees (reading bottom-up), as the
      # vertical-lr header cells did in the original HTML version.
      class VerticalTextCell < Prawn::Table::Cell::Text
        FONT_SIZE = 8

        def natural_content_width
          FONT_SIZE + 4
        end

        def natural_content_height
          @pdf.width_of(@content, size: FONT_SIZE) + 8
        end

        # Called inside a bounding box spanning the cell's content area
        # (local origin at its bottom-left corner). Rotating by 90 degrees
        # around that origin makes the text run upwards.
        def draw_content
          @pdf.rotate(90, origin: [0, 0]) do
            @pdf.font(@pdf.font.family, style: :bold) do
              baseline = (spanned_content_width / 2.0) + 3
              @pdf.draw_text(@content, at: [2, -baseline], size: FONT_SIZE)
            end
          end
        end
      end
    end
  end
end
