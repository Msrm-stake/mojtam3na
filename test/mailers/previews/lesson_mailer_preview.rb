# Preview every email at http://localhost:3000/rails/mailers (needs at least one lesson in the database).
class LessonMailerPreview < ActionMailer::Preview
  LOCALES = %w[en fr es it ru ar].freeze

  %w[booked cancelled reminder].each do |kind|
    LOCALES.each do |locale|
      define_method("#{kind}_parent_#{locale}") { build(kind, "parent", locale) }
    end
    define_method("#{kind}_teacher_en") { build(kind, "teacher", "en") }
  end

  private

  def build(kind, role, locale)
    lesson = Lesson.order(:id).last or raise "Book a lesson first (as a parent), then reload this page."
    user = role == "parent" ? lesson.booked_by : lesson.teacher_profile.user
    recipient = user.dup
    recipient.locale = locale

    LessonMailer.with(lesson: lesson, recipient: recipient, role: role, cancelled_by: "teacher").public_send(kind)
  end
end
