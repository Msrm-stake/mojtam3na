namespace :rtl do
  desc "Build app/assets/builds/application.rtl.css (compiled Sass flipped with RTLCSS)"
  task build: :environment do
    require "open3"
    require "fileutils"

    env = Rails.application.assets || Sprockets::Railtie.build_environment(Rails.application, true)
    asset = env.find_asset("application.css")
    abort "rtl:build: application.css not found" unless asset

    ltr_path = Rails.root.join("tmp/application.ltr.css")
    rtl_path = Rails.root.join("app/assets/builds/application.rtl.css")
    FileUtils.mkdir_p(File.dirname(ltr_path))
    FileUtils.mkdir_p(File.dirname(rtl_path))
    File.write(ltr_path, asset.to_s)

    output, status = Open3.capture2e("npx", "rtlcss", ltr_path.to_s, rtl_path.to_s)
    abort "rtl:build failed:\n#{output}" unless status.success?

    puts "Built #{rtl_path.relative_path_from(Rails.root)} (#{File.size(rtl_path)} bytes)"
  end
end
