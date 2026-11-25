# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_25_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "availability_slots", force: :cascade do |t|
    t.bigint "teacher_profile_id", null: false
    t.integer "weekday", null: false
    t.integer "start_minute", null: false
    t.integer "end_minute", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["teacher_profile_id", "weekday", "start_minute"], name: "idx_on_teacher_profile_id_weekday_start_minute_68c43fd71f"
    t.index ["teacher_profile_id"], name: "index_availability_slots_on_teacher_profile_id"
    t.check_constraint "start_minute >= 0 AND end_minute <= 1440 AND start_minute < end_minute", name: "availability_slots_minutes_range"
    t.check_constraint "weekday >= 0 AND weekday <= 6", name: "availability_slots_weekday_range"
  end

  create_table "consents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "student_id"
    t.string "kind", null: false
    t.string "ip_address"
    t.datetime "accepted_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_consents_on_student_id"
    t.index ["user_id"], name: "index_consents_on_user_id"
  end

  create_table "earnings", force: :cascade do |t|
    t.bigint "teacher_profile_id", null: false
    t.bigint "lesson_id", null: false
    t.bigint "order_id", null: false
    t.bigint "payout_id"
    t.integer "amount_cents", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.string "status", default: "available", null: false
    t.datetime "earned_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_earnings_on_lesson_id", unique: true
    t.index ["order_id"], name: "index_earnings_on_order_id", unique: true
    t.index ["payout_id"], name: "index_earnings_on_payout_id"
    t.index ["status"], name: "index_earnings_on_status"
    t.index ["teacher_profile_id"], name: "index_earnings_on_teacher_profile_id"
    t.check_constraint "amount_cents > 0", name: "earnings_positive_amount"
  end

  create_table "languages", force: :cascade do |t|
    t.string "code", limit: 8, null: false
    t.string "name", null: false
    t.string "native_name", null: false
    t.boolean "rtl", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_languages_on_code", unique: true
  end

  create_table "lessons", force: :cascade do |t|
    t.bigint "teacher_profile_id", null: false
    t.bigint "student_id", null: false
    t.bigint "booked_by_id", null: false
    t.bigint "cancelled_by_id"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "status", default: "scheduled", null: false
    t.boolean "trial", default: false, null: false
    t.integer "price_cents", default: 0, null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "reminder_sent_at"
    t.string "video_room_name"
    t.string "video_room_url"
    t.datetime "hold_expires_at"
    t.index ["booked_by_id"], name: "index_lessons_on_booked_by_id"
    t.index ["cancelled_by_id"], name: "index_lessons_on_cancelled_by_id"
    t.index ["student_id", "starts_at"], name: "index_lessons_on_student_id_and_starts_at"
    t.index ["student_id", "starts_at"], name: "index_lessons_one_active_per_student_slot", unique: true, where: "((status)::text = ANY ((ARRAY['scheduled'::character varying, 'pending_payment'::character varying])::text[]))"
    t.index ["student_id"], name: "index_lessons_on_student_id"
    t.index ["teacher_profile_id", "starts_at"], name: "index_lessons_on_teacher_profile_id_and_starts_at"
    t.index ["teacher_profile_id", "starts_at"], name: "index_lessons_one_active_per_teacher_slot", unique: true, where: "((status)::text = ANY ((ARRAY['scheduled'::character varying, 'pending_payment'::character varying])::text[]))"
    t.index ["teacher_profile_id"], name: "index_lessons_on_teacher_profile_id"
    t.index ["video_room_name"], name: "index_lessons_on_video_room_name", unique: true
    t.check_constraint "starts_at < ends_at", name: "lessons_start_before_end"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "lesson_id", null: false
    t.bigint "parent_id", null: false
    t.integer "amount_cents", null: false
    t.integer "commission_cents", null: false
    t.integer "teacher_amount_cents", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.string "stripe_refund_id"
    t.datetime "paid_at"
    t.datetime "refunded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id"], name: "index_orders_on_lesson_id", unique: true
    t.index ["parent_id"], name: "index_orders_on_parent_id"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["stripe_checkout_session_id"], name: "index_orders_on_stripe_checkout_session_id", unique: true
    t.index ["stripe_payment_intent_id"], name: "index_orders_on_stripe_payment_intent_id", unique: true
    t.check_constraint "amount_cents > 0 AND commission_cents >= 0 AND teacher_amount_cents >= 0 AND (commission_cents + teacher_amount_cents) = amount_cents", name: "orders_amounts_consistent"
  end

  create_table "payouts", force: :cascade do |t|
    t.bigint "teacher_profile_id", null: false
    t.date "period_start", null: false
    t.integer "amount_cents", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.string "status", default: "pending", null: false
    t.string "reference"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_payouts_on_status"
    t.index ["teacher_profile_id"], name: "index_payouts_on_teacher_profile_id"
    t.check_constraint "amount_cents > 0", name: "payouts_positive_amount"
  end

  create_table "qualifications", force: :cascade do |t|
    t.bigint "teacher_profile_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.string "institution"
    t.integer "year_obtained"
    t.string "status", default: "pending", null: false
    t.bigint "verified_by_id"
    t.datetime "verified_at"
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_qualifications_on_status"
    t.index ["teacher_profile_id"], name: "index_qualifications_on_teacher_profile_id"
    t.index ["verified_by_id"], name: "index_qualifications_on_verified_by_id"
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "students", force: :cascade do |t|
    t.bigint "parent_id", null: false
    t.string "first_name", null: false
    t.date "birth_date", null: false
    t.string "gender"
    t.bigint "native_language_id"
    t.string "arabic_level", default: "beginner", null: false
    t.string "quran_level", default: "beginner", null: false
    t.text "learning_goals"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["native_language_id"], name: "index_students_on_native_language_id"
    t.index ["parent_id"], name: "index_students_on_parent_id"
  end

  create_table "subjects", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_subjects_on_slug", unique: true
  end

  create_table "teacher_languages", force: :cascade do |t|
    t.bigint "teacher_profile_id", null: false
    t.bigint "language_id", null: false
    t.string "proficiency", default: "fluent", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id"], name: "index_teacher_languages_on_language_id"
    t.index ["teacher_profile_id", "language_id"], name: "index_teacher_languages_on_teacher_profile_id_and_language_id", unique: true
    t.index ["teacher_profile_id"], name: "index_teacher_languages_on_teacher_profile_id"
  end

  create_table "teacher_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.string "headline"
    t.text "bio"
    t.string "gender"
    t.integer "years_experience"
    t.string "intro_video_url"
    t.integer "hourly_rate_cents", default: 0, null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.integer "min_age"
    t.integer "max_age"
    t.string "stripe_account_id"
    t.boolean "stripe_payouts_enabled", default: false, null: false
    t.string "background_check_status", default: "not_started", null: false
    t.datetime "background_checked_at"
    t.bigint "approved_by_id"
    t.datetime "approved_at"
    t.text "rejection_reason"
    t.decimal "average_rating", precision: 3, scale: 2, default: "0.0", null: false
    t.integer "reviews_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payout_method"
    t.text "payout_details"
    t.datetime "payout_details_updated_at"
    t.datetime "photo_rejected_at"
    t.datetime "submitted_at"
    t.datetime "reminder_sent_at"
    t.integer "views_count", default: 0, null: false
    t.index ["approved_by_id"], name: "index_teacher_profiles_on_approved_by_id"
    t.index ["status"], name: "index_teacher_profiles_on_status"
    t.index ["user_id"], name: "index_teacher_profiles_on_user_id", unique: true
  end

  create_table "teacher_subjects", force: :cascade do |t|
    t.bigint "teacher_profile_id", null: false
    t.bigint "subject_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subject_id"], name: "index_teacher_subjects_on_subject_id"
    t.index ["teacher_profile_id", "subject_id"], name: "index_teacher_subjects_on_teacher_profile_id_and_subject_id", unique: true
    t.index ["teacher_profile_id"], name: "index_teacher_subjects_on_teacher_profile_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "role", default: "parent", null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "locale", default: "en", null: false
    t.string "country_code", limit: 2
    t.string "phone"
    t.string "stripe_customer_id"
    t.datetime "terms_accepted_at"
    t.datetime "deleted_at"
    t.string "terms_version"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "availability_slots", "teacher_profiles"
  add_foreign_key "consents", "students"
  add_foreign_key "consents", "users"
  add_foreign_key "earnings", "lessons"
  add_foreign_key "earnings", "orders"
  add_foreign_key "earnings", "payouts"
  add_foreign_key "earnings", "teacher_profiles"
  add_foreign_key "lessons", "students"
  add_foreign_key "lessons", "teacher_profiles"
  add_foreign_key "lessons", "users", column: "booked_by_id"
  add_foreign_key "lessons", "users", column: "cancelled_by_id"
  add_foreign_key "orders", "lessons"
  add_foreign_key "orders", "users", column: "parent_id"
  add_foreign_key "payouts", "teacher_profiles"
  add_foreign_key "qualifications", "teacher_profiles"
  add_foreign_key "qualifications", "users", column: "verified_by_id"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "students", "languages", column: "native_language_id"
  add_foreign_key "students", "users", column: "parent_id"
  add_foreign_key "teacher_languages", "languages"
  add_foreign_key "teacher_languages", "teacher_profiles"
  add_foreign_key "teacher_profiles", "users"
  add_foreign_key "teacher_profiles", "users", column: "approved_by_id"
  add_foreign_key "teacher_subjects", "subjects"
  add_foreign_key "teacher_subjects", "teacher_profiles"
end
