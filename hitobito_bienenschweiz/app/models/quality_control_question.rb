class QualityControlQuestion < ApplicationRecord
  belongs_to :quality_control_section

  validates :number, :title, :quality_control_section, presence: true
end
