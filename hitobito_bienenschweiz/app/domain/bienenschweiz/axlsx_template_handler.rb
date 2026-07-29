# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

module Bienenschweiz
  # ActionView template handler for `*.xlsx.axlsx` views, in the style of the
  # `axlsx_rails` gem: the template body is plain Ruby that builds a
  # spreadsheet against the `xlsx_package` (an Axlsx::Package) local variable.
  class AxlsxTemplateHandler
    def call(_template, source)
      "xlsx_package = ::Axlsx::Package.new\n#{source}\nxlsx_package.to_stream.read"
    end
  end
end
