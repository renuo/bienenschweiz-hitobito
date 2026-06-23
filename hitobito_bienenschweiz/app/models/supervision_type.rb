# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.


class SupervisionType < ApplicationRecord
  has_many :supervisions, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: true

  def to_s
    name
  end
end
