PKG_NAME=urepo
PKG_VERSION=2.2.2
PKG_DESCRIPTION="Universal repository for linux binary packages"

.PHONY: all
SHELL=/bin/bash

all: pkg
bin:
	gcc -Wall -O2 -o extract-post-file extract-post-file.c
clean:
	rm -rf extract-post-file build
pkg: bin
	mkdir build
	cp -r {var,etc} build/
	cp extract-post-file build/var/urepo/cgi
	cd build && \
	fpm --deb-user root --deb-group root \
	    -d nginx -d fcgiwrap -d createrepo \
	    --deb-no-default-config-files \
	    --description $(PKG_DESCRIPTION) \
	    --after-install ../after-install.sh \
	    --before-remove ../before-remove.sh \
	    -s dir -t deb -v $(PKG_VERSION) -n $(PKG_NAME) `find . -type f` && \
	find . ! -name '*.deb' -delete
