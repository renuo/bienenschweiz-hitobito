# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  class Checklist
    FONT_SIZE = 8
    FOOTER_HEIGHT = 24

    attr_reader :pdf, :qcontrol, :document

    def initialize(qcontrol)
      @document = Export::Pdf::Document.new(margin: [2.cm, 2.cm, 2.5.cm, 2.cm])
      @pdf = @document.pdf
      @pdf.font_size(FONT_SIZE)
      @qcontrol = qcontrol
    end

    def render
      sections.each { |section| section.new(pdf, qcontrol, {}).render }
      draw_footer
      pdf.render
    end

    def self.filename(qcontrol)
      parts = ["checkliste_betriebspruefung",
        qcontrol.person&.full_name,
        qcontrol.control_date&.strftime("%Y-%m-%d")].compact
      "#{parts.join("-").parameterize(separator: "_")}.pdf"
    end

    private

    def sections
      [Header, ControlInfo, Assessment, Notices, QuestionsTable]
    end

    # Draws a footer on every page, below the content area (within the bottom margin).
    def draw_footer
      pdf.repeat(:all) do
        pdf.bounding_box([0, 0], width: pdf.bounds.width, height: FOOTER_HEIGHT) do
          pdf.stroke { pdf.horizontal_rule }
          pdf.move_down(5)
          footer_texts
        end
      end
    end

    def footer_texts
      pdf.font_size(7.5) do
        pdf.text_box(I18n.t("checklist.footer.left"), at: [0, pdf.cursor])
        pdf.text_box(I18n.t("checklist.footer.right", year: Time.zone.today.year),
          at: [0, pdf.cursor], width: pdf.bounds.width, align: :right)
      end
    end
  end
end
