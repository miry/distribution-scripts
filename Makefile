.PHONY: docker-image
docker-image:
	make  -C linux 
	DOCKER_BUILDKIT=1 docker build -f Dockerfile -t opentracing-contrib/nginx-opentracing --target final .

.PHONY: test
test:
	./ci/system_testing.sh

.PHONY: clean
clean:
	rm -fr test-log
	rm -fr omnibus/local
	rm -fr omnibus/crystal-*
	make -C darwin clean
	rm -fr ~/tmp
	rm -fr ~/.cache/crystal
	rm -fr ~/.cache/shards

# https://github.com/chef/omnibus
.PHONY: setup
omnibus_setup:
	cd omnibus && bundle install --binstubs --path vendor/bundler
	
.PHONY: darwin
darwin: omnibus_setup
	FORCE_GIT_TAGGED=0 CRYSTAL_SRC=https://github.com/crystal-lang/crystal CRYSTAL_SHA1=master make -C darwin CRYSTAL_VERSION=1.10.1 PREVIOUS_CRYSTAL_RELEASE_DARWIN_TARGZ=https://github.com/crystal-lang/crystal/releases/download/1.10.1/crystal-1.10.1-1-darwin-universal.tar.gz
