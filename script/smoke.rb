# Checks the main flows in one run. Uses the development database and rolls everything back.
# Run with: bin/rails runner script/smoke.rb
ActionController::Base.allow_forgery_protection = false
ActionMailer::Base.delivery_method = :test
Warden.test_mode!
include Warden::Test::Helpers
Rack::Attack.enabled = true
Rack::Attack.cache.store.clear

puts "Ruby #{RUBY_VERSION}, Rails #{Rails.version}"
puts "default public file routes removed: #{!Rails.application.routes.url_helpers.method_defined?(:rails_blob_path)}"
puts "Action Cable endpoint switched off: #{Rails.application.routes.routes.none? { |r| r.path.spec.to_s.start_with?("/cable") }}"
puts "job tables in the main database: #{%w[solid_queue_jobs solid_queue_recurring_tasks solid_queue_processes].all? { |t| ActiveRecord::Base.connection.table_exists?(t) }}"
recurring = YAML.safe_load(ERB.new(File.read("config/recurring.yml")).result, aliases: true).fetch("production")
puts "scheduled jobs: #{recurring.keys.sort.inspect}, classes exist: #{recurring.values.filter_map { |t| t["class"] }.all? { |name| name.safe_constantize }}"

admin = User.role_admin.first or abort "No administrator account in the development database"
s = ActionDispatch::Integration::Session.new(Rails.application)
s.host! "localhost"

pages = %w[en fr es it ru ar].flat_map { |l| %w[/ /terms /privacy].map { |p| s.get("/#{l}#{p}"); ["/#{l}#{p}", s.response.status] } }
bad = pages.reject { |_, code| code == 200 }
puts "public pages in 6 languages: #{pages.size - bad.size} of #{pages.size} answer 200#{bad.empty? ? "" : " (not 200: #{bad.inspect})"}"

show_error = lambda do |label|
  next unless s.response.status == 500

  lines = File.readlines(Rails.root.join("log/development.log")).last(120)
  puts "  #{label} crashed: #{lines.grep(/Error|Exception/).first(3).map(&:strip).inspect}"
end

uploaded = []

ActiveRecord::Base.transaction do
  ActiveJob::Base.queue_adapter = :solid_queue
  LessonRemindersJob.perform_later
  puts "job stored in the main database: #{SolidQueue::Job.where(class_name: "LessonRemindersJob").exists?}"
  ActiveJob::Base.queue_adapter = :async

  make_teacher = lambda do |email|
    teacher = User.create!(email: email, password: "password123", first_name: "Amina", last_name: "Doc", role: "teacher", time_zone: "Paris")
    profile = teacher.teacher_profile
    profile.languages = Language.where(code: "ar")
    profile.subjects = Subject.where(slug: "tajweed")
    profile.update!(hourly_rate: 15)
    qualification = profile.qualifications.new(kind: "ijazah", title: "Ijazah test", status: "verified")
    qualification.save!(validate: false)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4 test"), filename: "ijazah.pdf", content_type: "application/pdf")
    uploaded << blob
    qualification.document.attach(blob)
    profile.approve!(admin)
    (1..6).each { |day| profile.availability_slots.create!(weekday: day, start_minute: 600, end_minute: 840) }
    [teacher, qualification]
  end

  teacher, qualification = make_teacher.call("t-doc@example.com")
  other_teacher, = make_teacher.call("t2-doc@example.com")
  parent = User.create!(email: "p-doc@example.com", password: "password123", first_name: "Pat", last_name: "D", role: "parent", time_zone: "Paris")
  child = parent.students.create!(first_name: "Sara", birth_date: 8.years.ago.to_date, guardian_consent: true)
  path = "/en/qualification-documents/#{qualification.id}"

  s.get path
  puts "document, not logged in: #{[s.response.status, s.response.location.to_s.include?("sign_in")].inspect}"
  login_as(teacher, scope: :user)
  s.get path
  puts "document, the teacher: #{[s.response.status, s.response.media_type, s.response.body.start_with?("%PDF"), s.response.headers["X-Content-Type-Options"], s.response.headers["Cache-Control"]].inspect}"
  show_error.call("teacher download")
  login_as(other_teacher, scope: :user)
  s.get path
  puts "document, another teacher: #{s.response.status}"
  login_as(parent, scope: :user)
  s.get path
  puts "document, a parent: #{s.response.status}"
  login_as(admin, scope: :user)
  s.get path
  puts "document, administrator: #{s.response.status}"
  show_error.call("administrator download")
  login_as(admin, scope: :user)
  s.get "/en/admin/teacher_profiles/#{teacher.teacher_profile.id}"
  puts "admin page links to the protected address: #{[s.response.status, s.response.body.include?(path)].inspect}"
  show_error.call("admin page")
  login_as(teacher, scope: :user)
  s.get "/en/teacher/profile/edit"
  puts "teacher page links to the protected address: #{[s.response.status, s.response.body.include?(path)].inspect}"
  show_error.call("teacher page")

  make_paid = lambda do |profile, index|
    start = profile.bookable_starts(minutes: 60).first
    lesson = Lesson.create!(teacher_profile: profile, student: child, booked_by: parent, trial: false, status: "pending_payment",
                            hold_expires_at: Lesson::HOLD_MINUTES.minutes.from_now, starts_at: start.utc,
                            ends_at: start.utc + 60.minutes, price_cents: 1500, currency: "EUR")
    order = Order.for_lesson(lesson)
    order.save!
    order.settle!({ "payment_status" => "paid", "payment_intent" => "pi_job_#{index}" })
    lesson.reload
  end

  ActionMailer::Base.deliveries.clear
  soon = make_paid.call(teacher.teacher_profile, 1)
  soon.update_columns(starts_at: 30.minutes.from_now, ends_at: 90.minutes.from_now)
  handled = LessonRemindersJob.perform_now
  recipients = ActionMailer::Base.deliveries.flat_map(&:to)
  puts "reminders job: #{[handled >= 1, recipients.include?("p-doc@example.com"), recipients.include?("t-doc@example.com")].inspect}"
  puts "reminded only once: #{!Lesson.needing_reminder.exists?(soon.id)}"

  finished = make_paid.call(other_teacher.teacher_profile, 2)
  finished.update_columns(starts_at: 50.hours.ago, ends_at: 49.hours.ago)
  result = PaymentsMaintenanceJob.perform_now
  puts "maintenance job: #{[result[:confirmed] >= 1, Earning.exists?(lesson_id: finished.id)].inspect}"

  uploaded.each { |blob| blob.service.delete(blob.key) }
  raise ActiveRecord::Rollback
end

fresh = ActionDispatch::Integration::Session.new(Rails.application)
fresh.host! "localhost"
ip = { "REMOTE_ADDR" => "203.0.113.50" }
bad_login = { user: { email: "someone@example.com", password: "wrong-password" } }
codes = 6.times.map { fresh.post("/en/users/sign_in", params: bad_login, env: ip); fresh.response.status }
puts "login: 5 tries allowed, then blocked: #{[codes.first(5).none? { |c| c == 429 }, codes.last].inspect}"
fresh.post "/en/users/sign_in", params: { user: { email: "another@example.com", password: "wrong-password" } }, env: ip
puts "another email on the same address still allowed: #{fresh.response.status != 429}"
fresh.get "/up", env: ip
puts "health check never blocked: #{fresh.response.status}"
fresh.post "/stripe/webhooks", params: "{}", headers: { "CONTENT_TYPE" => "application/json" }, env: ip
puts "Stripe webhook not blocked by the rate limit: #{fresh.response.status != 429}"
Rack::Attack.cache.store.clear

puts "--- committed files that look like secrets (expect none) ---"
puts `git ls-files | grep -E '(^|/)\\.env|master\\.key|\\.pem$'`.then { |out| out.strip.empty? ? "none" : out }
puts `git grep -nE 'sk_(live|test)_[A-Za-z0-9]{10,}|whsec_[A-Za-z0-9]{10,}|AKIA[0-9A-Z]{12,}' -- . ':!db' 2>/dev/null`.then { |out| out.strip.empty? ? "none" : out }
