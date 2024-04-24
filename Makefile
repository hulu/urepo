PKG_NAME=urepo
PKG_VERSION=2.2.6
PKG_DESCRIPTION="Universal repository for Linux binary packages"
PKG_URL=https://github.com/hulu/urepo
PKG_LICENSE="MIT License"
PKG_VENDOR="Hulu"
PKG_MAINTAINER="infra-eng@hulu.com"

.PHONY: all
SHELL=/bin/bash

all: pkg

bin:
	gcc -Wall -O2 -o extract-post-file extract-post-file.c

test: bin
	test/run-test.sh

clean:
	rm -rf extract-post-file build_${PKG_VERSION}

pkg: bin
	mkdir build_${PKG_VERSION}
	cp -r {var,etc} build_${PKG_VERSION}/
	cp extract-post-file build_${PKG_VERSION}/var/urepo/cgi
	cd build_${PKG_VERSION} && \
	fpm --deb-user root --deb-group root \
	    -d nginx -d fcgiwrap -d createrepo \
	    --deb-no-default-config-files \
	    --description $(PKG_DESCRIPTION) \
	    --license $(PKG_LICENSE) \
	    --vendor $(PKG_VENDOR) \
	    --maintainer $(PKG_MAINTAINER) \
	    --url $(PKG_URL) \
	    --after-install ../after-install.sh \
	    --before-remove ../before-remove.sh \
	    -s dir -t deb -v $(PKG_VERSION) -n $(PKG_NAME) `find . -type f` && \
	find . ! -name '*.deb' -delete
