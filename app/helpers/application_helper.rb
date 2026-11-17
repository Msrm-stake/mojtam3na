module ApplicationHelper
  LOCALE_NAMES = {
    en: "English", fr: "Français", es: "Español",
    it: "Italiano", ru: "Русский", ar: "العربية"
  }.freeze

  RTL_LOCALES = %i[ar].freeze

  # Monday first; 0 is Sunday (Ruby's wday)
  WEEKDAY_ORDER = [1, 2, 3, 4, 5, 6, 0].freeze

  def locale_name(locale)
    LOCALE_NAMES.fetch(locale.to_sym)
  end

  def rtl?
    RTL_LOCALES.include?(I18n.locale)
  end

  def text_direction
    rtl? ? "rtl" : "ltr"
  end

  # Arabic gets the RTL build (bin/rails rtl:build), other languages the normal one
  def main_stylesheet
    rtl? ? "application.rtl" : "application"
  end

  # Teachers are shown publicly as "Firstname L."
  def public_name(user)
    initial = user.last_name.to_s.strip[0]
    [user.first_name, initial && "#{initial}."].compact_blank.join(" ")
  end

  def teacher_price(profile)
    return t("teachers.price_not_set") if profile.hourly_rate_cents.zero?

    "#{format('%.2f', profile.hourly_rate)} #{profile.currency}"
  end

  def weekday_order
    WEEKDAY_ORDER
  end

  def weekday_name(wday)
    I18n.t("date.day_names")[wday].to_s.capitalize
  end

  # 570 => "09:30" (1440 => "24:00")
  def format_minutes(minutes)
    format("%02d:%02d", minutes / 60, minutes % 60)
  end

  def time_zone_label(name)
    ActiveSupport::TimeZone[name.to_s]&.to_s || name.to_s
  end

  # A moment in time, written in the viewer's time zone and language
  def format_lesson_time(time, zone)
    l(time.in_time_zone(zone), format: "%A %-d %B, %H:%M")
  end
end
