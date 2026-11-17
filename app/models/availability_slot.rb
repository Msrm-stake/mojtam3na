class AvailabilitySlot < ApplicationRecord
  STEP = 30
  MIN_LENGTH = 30

  belongs_to :teacher_profile

  validates :weekday, inclusion: { in: 0..6 }
  validates :start_minute, :end_minute, numericality: { only_integer: true }
  validate :times_must_be_valid
  validate :must_not_overlap

  private

  def times_must_be_valid
    return unless start_minute.is_a?(Integer) && end_minute.is_a?(Integer)

    errors.add(:start_minute, :invalid) unless start_minute.between?(0, 1439) && (start_minute % STEP).zero?
    errors.add(:end_minute, :invalid) unless end_minute.between?(1, 1440) && (end_minute % STEP).zero?
    errors.add(:end_minute, :too_early) if end_minute < start_minute + MIN_LENGTH
  end

  def must_not_overlap
    return unless teacher_profile && weekday && start_minute.is_a?(Integer) && end_minute.is_a?(Integer)

    clash = teacher_profile.availability_slots
                           .where(weekday: weekday)
                           .where.not(id: id)
                           .where("start_minute < ? AND end_minute > ?", end_minute, start_minute)
    errors.add(:base, :overlap) if clash.exists?
  end
end
