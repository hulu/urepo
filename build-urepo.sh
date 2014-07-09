#!/bin/bash

PKG_VERSION="1.3"
PKG_NAME="urepo"

PKG_DESCRIPTION="Universal repository for linux binary packages"
PKG_DEPENDENCIES="-d nginx-extras -d fcgiwrap -d createrepo -d apt-utils"

fpm --deb-user root --deb-group root \
    $PKG_DEPENDENCIES \
    --description "${PKG_DESCRIPTION}" \
    --after-install after-install.sh \
    --before-remove before-remove.sh \
    -a all -s dir -t deb -v ${PKG_VERSION} -n ${PKG_NAME} $(find {var/urepo,etc/urepo} -type f)

