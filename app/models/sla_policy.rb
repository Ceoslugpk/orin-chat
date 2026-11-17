class SlaPolicy < ApplicationRecord
  belongs_to :account
  has_many :conversations, dependent: :nullify

  validates :name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :description, length: { maximum: 255 }
  validates :first_response_time_threshold, :next_response_time_threshold, :resolution_time_threshold,
            numericality: { greater_than: 0 }, allow_nil: true
  validate :at_least_one_threshold

  private

  def at_least_one_threshold
    thresholds = [first_response_time_threshold, next_response_time_threshold, resolution_time_threshold]
    errors.add(:base, I18n.t('errors.sla_policy.at_least_one_threshold')) if thresholds.none?(&:present?)
  end
end
