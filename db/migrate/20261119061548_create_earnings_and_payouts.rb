class CreateEarningsAndPayouts < ActiveRecord::Migration[7.1]
  def change
    add_column :teacher_profiles, :payout_method, :string
    add_column :teacher_profiles, :payout_details, :text
    add_column :teacher_profiles, :payout_details_updated_at, :datetime

    create_table :payouts do |t|
      t.references :teacher_profile, null: false, foreign_key: true
      t.date     :period_start, null: false
      t.integer  :amount_cents, null: false
      t.string   :currency, null: false, default: "EUR", limit: 3
      t.string   :status, null: false, default: "pending"
      t.string   :reference
      t.datetime :paid_at
      t.timestamps
    end
    add_index :payouts, :status
    add_check_constraint :payouts, "amount_cents > 0", name: "payouts_positive_amount"

    create_table :earnings do |t|
      t.references :teacher_profile, null: false, foreign_key: true
      t.references :lesson, null: false, foreign_key: true, index: { unique: true }
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.references :payout, foreign_key: true
      t.integer  :amount_cents, null: false
      t.string   :currency, null: false, default: "EUR", limit: 3
      t.string   :status, null: false, default: "available"
      t.datetime :earned_at, null: false
      t.timestamps
    end
    add_index :earnings, :status
    add_check_constraint :earnings, "amount_cents > 0", name: "earnings_positive_amount"
  end
end
