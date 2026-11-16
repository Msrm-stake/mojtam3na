LANGUAGES = [
  ["en", "English", "English"],        ["fr", "French", "Français"],
  ["es", "Spanish", "Español"],        ["it", "Italian", "Italiano"],
  ["ru", "Russian", "Русский"],        ["ar", "Arabic", "العربية"],
  ["de", "German", "Deutsch"],         ["pt", "Portuguese", "Português"],
  ["nl", "Dutch", "Nederlands"],       ["tr", "Turkish", "Türkçe"],
  ["ur", "Urdu", "اردو"],              ["id", "Indonesian", "Bahasa Indonesia"],
  ["ms", "Malay", "Bahasa Melayu"],    ["bn", "Bengali", "বাংলা"],
  ["sw", "Swahili", "Kiswahili"]
].freeze

SUBJECTS = [
  ["arabic_reading", "Arabic reading and writing"],
  ["quran_recitation", "Quran recitation"],
  ["tajweed", "Tajweed"],
  ["memorization", "Memorization"],
  ["conversation", "Arabic conversation"]
].freeze

LANGUAGES.each do |code, name, native_name|
  Language.find_or_initialize_by(code: code)
          .update!(name: name, native_name: native_name, rtl: %w[ar ur].include?(code))
end

SUBJECTS.each do |slug, name|
  Subject.find_or_initialize_by(slug: slug).update!(name: name)
end

puts "Seeded #{Language.count} languages and #{Subject.count} subjects"
