class CreateAvailabilitySlots < ActiveRecord::Migration[7.1]
  def change
    create_table :availability_slots do |t|
      t.references :teacher_profile, null: false, foreign_key: true
      t.integer :weekday, null: false
      t.integer :start_minute, null: false
      t.integer :end_minute, null: false
      t.timestamps
    end

    add_index :availability_slots, %i[teacher_profile_id weekday start_minute]
    add_check_constraint :availability_slots, "weekday BETWEEN 0 AND 6",
                         name: "availability_slots_weekday_range"
    add_check_constraint :availability_slots,
                         "start_minute >= 0 AND end_minute <= 1440 AND start_minute < end_minute",
                         name: "availability_slots_minutes_range"
  end
end
