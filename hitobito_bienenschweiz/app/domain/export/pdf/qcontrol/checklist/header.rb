# frozen_string_literal: true

# Copyright (c) 2012-2026. BienenSchweiz. This file is part of
# hitobito_bienenschweiz and licensed under the Affero General Public License version 3
# or later. See the COPYING file at the top-level directory or at
# https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz

module Export::Pdf::Qcontrol
  class Checklist
    class Header < Section
      LOGO_WIDTH = 90
      # original logo is 138x112 px
      LOGO_HEIGHT = LOGO_WIDTH * 112.0 / 138
      TEXT_OFFSET = LOGO_WIDTH + 20

      def render
        top = cursor
        image(logo_path, at: [0, top], width: LOGO_WIDTH)
        description(top)
        move_cursor_to([cursor, top - LOGO_HEIGHT].min)
        pdf.move_down(10)
      end

      private

      def description(top)
        bounding_box([TEXT_OFFSET, top], width: bounds.width - TEXT_OFFSET) do
          text(t("title"), size: 13, style: :bold)
          text(t("subtitle"), size: 10, style: :bold)
          pdf.move_down(4)
          text(t("header_description"))
        end
      end

      def logo_path
        HitobitoBienenschweiz::Wagon.root.join("app/assets/images/logo_bw.png")
      end
    end
  end
end
