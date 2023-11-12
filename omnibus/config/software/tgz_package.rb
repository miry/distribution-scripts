name "tgz_package"
default_version "0.0.1"
skip_transitive_dependency_licensing true

build do
  block do
    destination = File.expand_path('pkg', Omnibus::Config.project_root)
    version = "#{project.build_version}-#{project.build_iteration}"
    version.gsub!("/", "-")
    tgz_name = "#{project.name}-#{version}-#{ohai['os']}-universal.tar.gz"
    if macos? || mac_os_x?
      transform = "-s /./#{project.name}-#{version}/"
    else
      transform = %(--transform="s/./#{project.name}-#{version}/")
    end

    command "tar czf #{destination}/#{tgz_name} #{transform} -C #{install_dir} .",
      env: {"COPYFILE_DISABLE" => "1"}
    
    # NOTE: hack to bypass `git_caching` to modify anything in the working directory to create a commit
    command "date > #{install_dir}/tgz_package.log"
  end
end
