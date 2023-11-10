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

# https://github.com/chef/omnibus
.PHONY: setup
omnibus_setup:
	cd omnibus && bundle install --binstubs --path vendor/bundler
	

.PHONY: darwin
darwin: omnibus_setup
	make -C darwin CRYSTAL_VERSION=1.10.1 PREVIOUS_CRYSTAL_RELEASE_DARWIN_TARGZ=https://github.com/crystal-lang/crystal/releases/download/1.10.1/crystal-1.10.1-1-darwin-universal.tar.gz
