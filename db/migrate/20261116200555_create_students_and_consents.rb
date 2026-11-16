class CreateStudentsAndConsents < ActiveRecord::Migration[7.1]
  def change
    create_table :students do |t|
      t.references :parent, null: false, foreign_key: { to_table: :users }
      t.string  :first_name, null: false
      t.date    :birth_date, null: false
      t.string  :gender
      t.references :native_language, foreign_key: { to_table: :languages }
      t.string  :arabic_level, null: false, default: "beginner"
      t.string  :quran_level, null: false, default: "beginner"
      t.text    :learning_goals
      t.timestamps
    end

    create_table :consents do |t|
      t.references :user, null: false, foreign_key: true
      t.references :student, foreign_key: true
      t.string   :kind, null: false
      t.string   :ip_address
      t.datetime :accepted_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
  end
end
