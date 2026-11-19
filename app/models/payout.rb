class Payout < ApplicationRecord
  # Balances below this wait for the next month (change it here; 0 pays every balance).
  MINIMUM_CENTS = 2000

  belongs_to :teacher_profile
  has_many :earnings, dependent: :restrict_with_error

  enum :status, { pending: "pending", paid: "paid", cancelled: "cancelled" }, prefix: true

  validates :period_start, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :reference, presence: true, if: :status_paid?
  validates :reference, length: { maximum: 200 }

  # Groups each teacher's confirmed earnings (up to the end of the given month) into one pending payout.
  # Returns the payouts created and the teachers who had to wait (no payout details, or below the minimum).
  def self.prepare!(month_start)
    month_start = month_start.beginning_of_month
    cutoff = month_start.next_month.in_time_zone("UTC")
    result = { created: [], missing_details: [], below_minimum: [] }

    teacher_ids = Earning.status_available.where("earned_at < ?", cutoff).distinct.pluck(:teacher_profile_id)
    TeacherProfile.where(id: teacher_ids).includes(:user).find_each do |profile|
      transaction do
        earnings = profile.earnings.status_available.where("earned_at < ?", cutoff).lock.to_a
        next if earnings.empty?

        total = earnings.sum(&:amount_cents)
        if !profile.payout_ready?
          result[:missing_details] << profile
        elsif total < MINIMUM_CENTS
          result[:below_minimum] << profile
        else
          payout = create!(teacher_profile: profile, period_start: month_start, amount_cents: total, currency: "EUR")
          Earning.where(id: earnings.map(&:id)).update_all(status: "in_payout", payout_id: payout.id, updated_at: Time.current)
          result[:created] << payout
        end
      end
    end

    result
  end

  def mark_paid!(reference)
    done = false
    with_lock do
      if status_pending?
        update!(status: "paid", reference: reference.to_s.strip, paid_at: Time.current)
        earnings.update_all(status: "paid_out", updated_at: Time.current)
        done = true
      end
    end
    done
  end

  # Gives the earnings back to the teacher's balance so they can go into a later payout.
  def cancel!
    done = false
    with_lock do
      if status_pending?
        earnings.update_all(status: "available", payout_id: nil, updated_at: Time.current)
        update!(status: "cancelled")
        done = true
      end
    end
    done
  end
end
