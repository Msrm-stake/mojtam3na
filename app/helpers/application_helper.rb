module ApplicationHelper
  LOCALE_NAMES = {
    en: "English", fr: "Français", es: "Español",
    it: "Italiano", ru: "Русский", ar: "العربية"
  }.freeze

  RTL_LOCALES = %i[ar].freeze

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
end
