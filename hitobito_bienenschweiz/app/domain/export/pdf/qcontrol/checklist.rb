# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  class Checklist

    attr_reader :pdf, :qcontrol, :document

    delegate :bounds, :bounding_box, :cursor, :font_size, to: :pdf

    def initialize(qcontrol)
      @document = Export::Pdf::Document.new
      @pdf = @document.pdf
      @qcontrol = qcontrol
    end

    def render
      bounding_box([bounds.left, bounds.top], width: bounds.width, height: bounds.height - 5.mm) do
        pdf.move_down 40
        pdf.text('TEST', style: :bold, size: 16)
      end
      pdf.render
    end

    def self.filename(qcontrol)
      'checklist.pdf'
    end
  end
end
