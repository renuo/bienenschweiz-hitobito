# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.
#
#  Ported from hitobito_sac_cas.

module Invoices
  module Abacus
    module ClientRequestMethods
      private

      def request_body(method, params)
        encode_json(params) if params && method != :get
      end

      def request_path(method, path, params)
        if params && method == :get
          # Abacus does not decode "+" as space (e.g. in "$orderby=Id desc")
          "#{path}?#{URI.encode_www_form(params).gsub("+", "%20")}"
        else
          path
        end
      end
    end
  end
end
