#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

# Only show the results belonging to the selected supervision kind and
# disable the supervisor selection for feedbacks.
$(document).on 'change', '[data-supervision-kind]', ->
  kind = $(this).val()
  options = $('[data-supervision-result] option')
  options.each -> @hidden = true
  visible = options.filter("[data-kind=#{kind}]")
  visible.each -> @hidden = false
  $('[data-supervision-result]').val(visible.first().val())
  $('[data-supervision-supervisor]').val(null).prop('disabled', kind != 'supervision')
