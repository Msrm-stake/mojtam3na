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
end
