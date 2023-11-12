SHARDS_VERSION = "0.17.4"

name "shards"
default_version SHARDS_VERSION
skip_transitive_dependency_licensing true

dependency "crystal"
dependency "libyaml"

version "0.7.2" do
  source md5: "4f1f1e860ed1846fce01581ce9e6e7ad"
end

version "0.8.0" do
  source md5: "f0a52e64537ea6267a2006195e818c4d"
end

version "0.8.1" do
  source md5: "f5b5108d798b1d86d2b9b45c3a2b5293"
end

version "0.10.0" do
  source md5: "f982f2dc0c796763205bd0de68e9f87e"
end

version "0.11.0" do
  source md5: "a16d6580411152956363a766e1517c9d"
end

version "0.11.1" do
  source md5: "6924888dffc158e2e1a10f8ec9c65cb0"
end

version "0.12.0" do
  source md5: "c65327561cfbb0c465ec4bd945423fe9"
end

version "0.13.0" do
  source md5: "a66b767ad9914472c23e1cb76446fead"
end

version "0.14.1" do
  source md5: "d7bdd10bb096b71428b06fc93097b3cc"
end

version "0.15.0" do
  source md5: "696525e924350a1270eee5c221eb6c80"
end

version "0.16.0" do
  source md5: "60bc6791fa94f3068b7580dd8cde5d1a"
end

version "0.17.0" do
  source md5: "04bdf5739ea4a897267502b9f77ec46f"
end

version "0.17.1" do
  source md5: "8bca944b1bbac88223e1bedcbc23eed0"
end

version "0.17.2" do
  source md5: "2f0ae55946c413bbbb4e4dce204a81e7"
end

version "0.17.3" do
  source md5: "1fc2b19765e28a6bbf16291caf9cf62c"
end

version "0.17.4" do
  source md5: "9215e617238ae297bedf639e574d28d5"
end

source url: "https://github.com/crystal-lang/shards/archive/v#{version}.tar.gz"

relative_path "shards-#{version}"
env = with_standard_compiler_flags(with_embedded_path(
  "LIBRARY_PATH" => "#{install_dir}/embedded/lib",
  "CRYSTAL_LIBRARY_PATH" => "#{install_dir}/embedded/lib"
))
env["CFLAGS"] << " -fPIC -arch arm64 -arch x86_64"
env["CPPFLAGS"] = env["CPPFLAGS"].gsub("-arch arm64 -arch x86_64", "")

build do
  block { puts "\n=== Starting build phase for shards from #{project_dir} ===\n\n" }

  make "clean", env: env
  command "#{install_dir}/bin/crystal clear_cache"

  # Build for x86_64
  crflags = "--no-debug --release"
  block { puts "\n===== 1. Building shards x86_64 version\n\n" }
  crflags_x86_64 = crflags + " --cross-compile --target x86_64-apple-darwin"
  make "bin/shards SHARDS=false CRYSTAL=#{install_dir}/bin/crystal FLAGS='#{crflags_x86_64}'", env: env

  output_bin = "#{project_dir}/bin/shards"
  output_bin_x86_64 = "#{output_bin}_x86_64"
  target_x86_64 = 'x86_64-apple-darwin'
  command "clang bin/shards.o -o #{output_bin_x86_64} -v -target #{target_x86_64} -L#{install_dir}/embedded/lib -lyaml -lpcre2-8 -lgc -lpthread -levent -liconv -ldl", env: env
  block "Testing the result file" do
    puts "===== >>> Testing the result file #{output_bin_x86_64} in #{project_dir}}"
    raise "Could not build #{output_bin_x86_64}" unless File.exist?(output_bin_x86_64)
  end
  # TODO: Add a validation of the output to check archs
  command "file #{output_bin_x86_64}", env: env.dup

  # Clean
  make "clean", env: env
  command "#{install_dir}/bin/crystal clear_cache"

  # Build for arm64
  block { puts "\n===== 2. Building shards arm64 version\n\n" }
  crflags_arm = crflags + " --cross-compile --target aarch64-apple-darwin"
  make "bin/shards SHARDS=false CRYSTAL=#{install_dir}/bin/crystal FLAGS='#{crflags_arm}'", env: env
  output_bin_arm64 = "#{output_bin}_arm64"
  target_arm64 = 'arm64-apple-darwin'
  command "clang bin/shards.o -o #{output_bin_arm64} -v -target #{target_arm64} -L#{install_dir}/embedded/lib -lyaml -lpcre2-8 -lgc -lpthread -levent -liconv -ldl", env: env
  block "Testing the result file" do
    puts "===== >>> Testing the result file #{output_bin_arm64}"
    raise "Could not build #{output_bin_arm64}" unless File.exist?("#{output_bin_arm64}")
  end
  # TODO: Add a validation of the output to check archs
  command "file #{output_bin_arm64}", env: env.dup

  # Lipo them up
  block { puts "\n===== 3. Combine x86_64 and arm64 binaries in a single universal binary\n\n" }
  command "lipo -create -output #{output_bin} #{output_bin_x86_64} #{output_bin_arm64}"
  block "Testing the result file" do
    puts "===== >>> Testing the result file #{output_bin}"
    raise "Could not build #{output_bin}: #{output_bin}" unless File.exist?("#{output_bin}")
  end
  # TODO: Add a validation of the output to check archs
  command "file #{output_bin}", env: env.dup

  copy "bin/shards", "#{install_dir}/embedded/bin/shards"

  block { puts "\n===< Shards successfully built\n\n" }
end
