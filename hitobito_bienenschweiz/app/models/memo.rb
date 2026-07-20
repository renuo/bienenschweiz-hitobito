# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class Memo < ApplicationRecord
  belongs_to :person
  belongs_to :author, class_name: "Person", optional: true

  validates_by_schema
  validates :title, :body, presence: true

  before_create :set_author_name

  def to_s
    title
  end

  private

  def set_author_name
    self.author_name = author.full_name if author.present?
  end
end
