CRYSTAL_VERSION = ENV['CRYSTAL_VERSION']
CRYSTAL_SHA1 = ENV['CRYSTAL_SHA1']
FIRST_RUN = ENV["FIRST_RUN"]
CRYSTAL_SRC = ENV.fetch('CRYSTAL_SRC', 'https://github.com/crystal-lang/crystal')

name "crystal"
default_version CRYSTAL_VERSION
skip_transitive_dependency_licensing true

source git: CRYSTAL_SRC

dependency "pcre2"
dependency "bdw-gc"
dependency "llvm_bin" unless FIRST_RUN
dependency "libevent"
dependency "libffi"

env = with_standard_compiler_flags(with_embedded_path(
  "LIBRARY_PATH" => "#{install_dir}/embedded/lib",
  "CRYSTAL_LIBRARY_PATH" => "#{install_dir}/embedded/lib",
))
env["CFLAGS"] << " -fPIC -arch arm64 -arch x86_64"
env["CPPFLAGS"] = env["CPPFLAGS"].gsub("-arch arm64 -arch x86_64", "")

unless FIRST_RUN
  llvm_bin = Omnibus::Software.load(project, "llvm_bin", nil)
end

output_path = "#{install_dir}/embedded/bin"
output_bin = "#{output_path}/crystal"
output_bin_x86_64 = "#{output_path}/crystal_x86_64"
output_bin_arm = "#{output_path}/crystal_arm"

path_env = "#{project_dir}/deps:#{env["PATH"]}"
unless FIRST_RUN
  path_env = "#{llvm_bin.project_dir}/bin:#{path_env}"
end
env["PATH"] = path_env

# raise Omnibus::Config.cache_dir.inspect

if macos? || mac_os_x?
  env["CRYSTAL_PATH"] = "lib:/private/var/cache/omnibus/src/crystal/src:#{project_dir}/src"
else
  env["CRYSTAL_PATH"] = "lib:#{project_dir}/src"
end

build do
  block { puts "\n===> Starting build phase for crystal from #{Dir.pwd} ===\n\n" }
  command "echo '    Sources are located in #{project_dir}'", env: env.dup

  command "git checkout '#{CRYSTAL_SHA1}'", cwd: project_dir

  block { puts "\n===== 1. Build native crystal bin with embedded universal crystal binary\n\n" }
  mkdir "#{project_dir}/deps"
  make "deps", env: env.dup
  mkdir ".build"

  copy "#{Dir.pwd}/crystal-#{ohai['os']}/embedded/bin/crystal", ".build/crystal"
  command ".build/crystal --version", env: env.dup
  command "file .build/crystal", env: env.dup

  # Compile native
  crflags = "--no-debug"
  command "make crystal stats=true release=true FLAGS=\"#{crflags}\" CRYSTAL_CONFIG_LIBRARY_PATH= O=#{output_path}", env: env.dup
  block "Testing the result file" do
    puts "===== >>> Testing the result file #{output_bin}"
    raise "Could not build native crystal: #{output_bin}" unless File.exist?("#{output_bin}")
  end
  # TODO: Add validation of command output
  command "file #{output_bin}", env: env.dup

  block { puts "\n===== 2. Restore compiler with cross-compile support\n\n" }
  # Restore compiler w/ cross-compile support
  move "#{output_bin}", ".build/crystal"
  command ".build/crystal --version", env: env.dup

  # Clean up
  make "clean_cache clean", env: env

  block { puts "\n===== 3. Building crystal x86_64 version\n\n" }

  original_CXXFLAGS_env = env["CXXFLAGS"].dup
  original_LDFLAGS_env = env["LDFLAGS"].dup

  # Build for x86_64
  env["CXXFLAGS"] = original_CXXFLAGS_env + " -target x86_64-apple-darwin"
  env["LDFLAGS"] = original_LDFLAGS_env + " -v -target x86_64-apple-darwin"
  env["LDLIBS"] = "-v -target x86_64-apple-darwin"
  make "deps", env: env.dup

  make "crystal verbose=true stats=true release=true target=x86_64-apple-darwin FLAGS=\"#{crflags}\" CRYSTAL_CONFIG_TARGET=x86_64-apple-darwin CRYSTAL_CONFIG_LIBRARY_PATH= O=#{output_path}", env: env
  command "clang #{output_path}/crystal.o -o #{output_bin_x86_64} -target x86_64-apple-darwin src/llvm/ext/llvm_ext.o `llvm-config --libs --system-libs --ldflags 2>/dev/null` -lstdc++ -lpcre2-8 -lgc -lpthread -levent -liconv -ldl -v", env: env

  # Assertion
  block { raise "Could not build #{output_bin_x86_64}" unless File.exist?(output_bin_x86_64) }
  command "file #{output_bin_x86_64}", env: env

  # Clean up
  delete "#{output_path}/crystal.o"
  make "clean_cache clean", env: env

  # Build for arm64
  block { puts "\n===== 4. Building crystal arm64 version\n\n" }

  # Compile for ARM64. Apple's clang only understands arm64, LLVM uses aarch64,
  # so we need to sub out aarch64 in our calls to Apple tools
  env["CXXFLAGS"] = original_CXXFLAGS_env + " -target arm64-apple-darwin"
  env["LDFLAGS"] = original_LDFLAGS_env + " -v -target arm64-apple-darwin"
  env["LDLIBS"] = "-v -target x86_64-apple-darwin"
  make "deps", env: env.dup
  make "crystal verbose=true stats=true release=true target=aarch64-apple-darwin FLAGS=\"#{crflags}\" CRYSTAL_CONFIG_TARGET=aarch64-apple-darwin CRYSTAL_CONFIG_LIBRARY_PATH= O=#{output_path}", env: env
  command "clang #{output_path}/crystal.o -o #{output_bin_arm} -target arm64-apple-darwin src/llvm/ext/llvm_ext.o `llvm-config --libs --system-libs --ldflags 2>/dev/null` -lstdc++ -lpcre2-8 -lgc -lpthread -levent -liconv -ldl -v", env: env

  # Assertion
  block { raise "Could not build #{output_bin_arm}" unless File.exist?(output_bin_arm) }
  command "file #{output_bin_arm}", env: env

  # Clean up
  delete "#{output_path}/crystal.o"

  # Lipo them up
  block { puts "\n===== 5. Combine x86_64 and arm64 binaries in single crystal universal binary\n\n" }
  command "lipo -create -output #{output_bin} #{output_bin_x86_64} #{output_bin_arm}"

  block do
    puts "===== >>> Testing the result file #{output_bin}"
    raise "Could not build universal crystal #{output_bin}" unless File.exist?(output_bin)
  end
  # TODO: Add validation of command output
  command "file #{output_bin}", env: env.dup

  # Clean up
  delete output_bin_x86_64
  delete output_bin_arm
  make "clean_cache clean", env: env

  block do
    if macos? || mac_os_x?
      otool_libs = `otool -L #{output_bin}`
      if otool_libs.include?("/usr/local/lib") || otool_libs.include?('/opt/homebrew/lib')
        raise "Found local libraries linked to the generated compiler:\n#{otool_libs}"
      end
    end
  end

  sync "#{project_dir}/src", "#{install_dir}/src"
  sync "#{project_dir}/etc", "#{install_dir}/etc"
  sync "#{project_dir}/samples", "#{install_dir}/samples"
  mkdir "#{install_dir}/bin"

  erb source: "crystal.erb",
      dest: "#{install_dir}/bin/crystal",
      mode: 0755,
      vars: { install_dir: install_dir }

  block { puts "\n===< Crystal successfully built\n\n" }
end
