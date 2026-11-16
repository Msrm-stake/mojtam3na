class CreateTeacherProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :languages do |t|
      t.string  :code, null: false, limit: 8
      t.string  :name, null: false
      t.string  :native_name, null: false
      t.boolean :rtl, null: false, default: false
      t.timestamps
    end
    add_index :languages, :code, unique: true

    create_table :subjects do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :subjects, :slug, unique: true

    create_table :teacher_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string  :status, null: false, default: "pending"
      t.string  :headline
      t.text    :bio
      t.string  :gender
      t.integer :years_experience
      t.string  :intro_video_url
      t.integer :hourly_rate_cents, null: false, default: 0
      t.string  :currency, null: false, default: "EUR", limit: 3
      t.integer :min_age
      t.integer :max_age
      t.string  :stripe_account_id
      t.boolean :stripe_payouts_enabled, null: false, default: false
      t.string  :background_check_status, null: false, default: "not_started"
      t.datetime :background_checked_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.text    :rejection_reason
      t.decimal :average_rating, precision: 3, scale: 2, null: false, default: 0
      t.integer :reviews_count, null: false, default: 0
      t.timestamps
    end
    add_index :teacher_profiles, :status

    create_table :teacher_languages do |t|
      t.references :teacher_profile, null: false, foreign_key: true
      t.references :language, null: false, foreign_key: true
      t.string :proficiency, null: false, default: "fluent"
      t.timestamps
    end
    add_index :teacher_languages, %i[teacher_profile_id language_id], unique: true

    create_table :teacher_subjects do |t|
      t.references :teacher_profile, null: false, foreign_key: true
      t.references :subject, null: false, foreign_key: true
      t.timestamps
    end
    add_index :teacher_subjects, %i[teacher_profile_id subject_id], unique: true

    create_table :qualifications do |t|
      t.references :teacher_profile, null: false, foreign_key: true
      t.string  :kind, null: false
      t.string  :title, null: false
      t.string  :institution
      t.integer :year_obtained
      t.string  :status, null: false, default: "pending"
      t.references :verified_by, foreign_key: { to_table: :users }
      t.datetime :verified_at
      t.text    :admin_notes
      t.timestamps
    end
    add_index :qualifications, :status
  end
end
