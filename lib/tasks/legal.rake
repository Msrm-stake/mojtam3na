namespace :legal do
  desc "Fails while config/legal.yml still contains [PLACEHOLDERS]"
  task check: :environment do
    missing = Legal.missing
    abort "Legal details incomplete. Still to fill in config/legal.yml: #{missing.join(', ')}" if missing.any?

    puts "Legal details complete."
  end

  desc "Run before each deployment: fails on [PLACEHOLDERS] only when REQUIRE_LEGAL_COMPLETE=true"
  task gate: :environment do
    if ENV["REQUIRE_LEGAL_COMPLETE"] == "true"
      Rake::Task["legal:check"].invoke
    else
      puts "Legal gate skipped (REQUIRE_LEGAL_COMPLETE is not true). Details still missing: #{Legal.missing.size}"
    end
  end
end
