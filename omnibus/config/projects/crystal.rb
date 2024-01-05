name 'crystal'
maintainer 'Juan Wajnerman'
homepage 'http://crystal-lang.org/'

install_dir File.join(ENV.fetch('HOME'), '/tmp/crystal')
build_version do
  source :version, from_dependency: 'crystal'
end
build_iteration ENV['PACKAGE_ITERATION']

dependency 'crystal'
dependency 'shards'
dependency 'tgz_package'

exclude '\.git*'
exclude 'bundler\/git'
