namespace :legal do
  desc "Fails while config/legal.yml still contains [PLACEHOLDERS] (run before every deployment)"
  task check: :environment do
    missing = Legal.missing
    abort "Legal details incomplete. Still to fill in config/legal.yml: #{missing.join(', ')}" if missing.any?

    puts "Legal details complete."
  end
end
