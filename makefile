.PHONY: all
SHELL=/bin/bash

all: pkg
bin:
	gcc -Wall -O2 -o extract-post-file extract-post-file.c
clean:
	rm -rf extract-post-file build *.deb
test: bin
	test/run-test.sh
pkg: test
	mkdir -p build
	rm -rf build/*
	cp -r {var,etc} build/
	cp -r DEBIAN.urepo build/DEBIAN
	cp extract-post-file build/var/urepo/cgi
	chmod -R go-w build
	. <(grep -E "^(Package|Version|Architecture):" build/DEBIAN/control |sed -e 's/: \(.*\)/="\1"/') && \
	dpkg-deb --root-owner-group -b ./build $${Package}_$${Version}_$${Architecture}.deb
uploader:
	mkdir -p build
	rm -rf build/*
	cp -r usr build/
	cp -r DEBIAN.urepo-uploader build/DEBIAN
	chmod -R go-w build
	. <(grep -E "^(Package|Version|Architecture):" build/DEBIAN/control |sed -e 's/: \(.*\)/="\1"/') && \
	dpkg-deb --root-owner-group -b ./build $${Package}_$${Version}_$${Architecture}.deb
