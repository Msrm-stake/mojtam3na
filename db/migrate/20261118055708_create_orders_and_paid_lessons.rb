class CreateOrdersAndPaidLessons < ActiveRecord::Migration[7.1]
  def change
    add_column :lessons, :hold_expires_at, :datetime

    create_table :orders do |t|
      t.references :lesson, null: false, foreign_key: true, index: { unique: true }
      t.references :parent, null: false, foreign_key: { to_table: :users }
      t.integer  :amount_cents, null: false
      t.integer  :commission_cents, null: false
      t.integer  :teacher_amount_cents, null: false
      t.string   :currency, null: false, default: "EUR", limit: 3
      t.string   :status, null: false, default: "pending"
      t.string   :stripe_checkout_session_id
      t.string   :stripe_payment_intent_id
      t.string   :stripe_refund_id
      t.datetime :paid_at
      t.datetime :refunded_at
      t.timestamps
    end

    add_index :orders, :stripe_checkout_session_id, unique: true
    add_index :orders, :stripe_payment_intent_id, unique: true
    add_index :orders, :status
    add_check_constraint :orders,
                         "amount_cents > 0 AND commission_cents >= 0 AND teacher_amount_cents >= 0 " \
                         "AND commission_cents + teacher_amount_cents = amount_cents",
                         name: "orders_amounts_consistent"

    # A lesson waiting for payment must block its time too, so the unique indexes now cover it.
    remove_index :lessons, column: %i[teacher_profile_id starts_at], unique: true,
                           where: "status = 'scheduled'", name: "index_lessons_one_scheduled_per_teacher_slot"
    remove_index :lessons, column: %i[student_id starts_at], unique: true,
                           where: "status = 'scheduled'", name: "index_lessons_one_scheduled_per_student_slot"
    add_index :lessons, %i[teacher_profile_id starts_at], unique: true,
              where: "status IN ('scheduled', 'pending_payment')", name: "index_lessons_one_active_per_teacher_slot"
    add_index :lessons, %i[student_id starts_at], unique: true,
              where: "status IN ('scheduled', 'pending_payment')", name: "index_lessons_one_active_per_student_slot"
  end
end
