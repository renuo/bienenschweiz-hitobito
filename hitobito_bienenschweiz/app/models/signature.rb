# frozen_string_literal: true

#  Copyright (c) 2012-2026, BienenSchweiz. This file is part of
#  hitobito_bienenschweiz and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/renuo/bienenschweiz-hitobito/tree/develop/hitobito_bienenschweiz.

class Signature < ApplicationRecord
  has_one_attached :image

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  ALLOWED_IMAGE_TYPES = %w[image/png image/jpeg].freeze
  validates :image, content_type: ALLOWED_IMAGE_TYPES

  def remove_image
    false
  end

  def remove_image=(val)
    image.purge_later if ActiveRecord::Type::Boolean.new.cast(val)
  end

  def to_s
    name
  end

  def prawn_compatible?
    ALLOWED_IMAGE_TYPES.include?(image.blob.content_type)
  end
end
