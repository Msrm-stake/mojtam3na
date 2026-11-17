class CreateLessons < ActiveRecord::Migration[7.1]
  def change
    create_table :lessons do |t|
      t.references :teacher_profile, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.references :booked_by, null: false, foreign_key: { to_table: :users }
      t.references :cancelled_by, foreign_key: { to_table: :users }
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string   :status, null: false, default: "scheduled"
      t.boolean  :trial, null: false, default: false
      t.integer  :price_cents, null: false, default: 0
      t.string   :currency, null: false, default: "EUR", limit: 3
      t.datetime :cancelled_at
      t.timestamps
    end

    add_index :lessons, %i[teacher_profile_id starts_at]
    add_index :lessons, %i[student_id starts_at]

    # The database itself refuses a double booking, even if two parents click at the same moment.
    add_index :lessons, %i[teacher_profile_id starts_at], unique: true, where: "status = 'scheduled'",
              name: "index_lessons_one_scheduled_per_teacher_slot"
    add_index :lessons, %i[student_id starts_at], unique: true, where: "status = 'scheduled'",
              name: "index_lessons_one_scheduled_per_student_slot"

    add_check_constraint :lessons, "starts_at < ends_at", name: "lessons_start_before_end"
  end
end
