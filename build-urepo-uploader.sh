#!/bin/bash

PKG_VERSION="1.2"
PKG_NAME="urepo-uploader"

PKG_DESCRIPTION="Uploading tool for urepo (universal repository for linux binary packages)"

fpm --deb-user root --deb-group root \
    --description "${PKG_DESCRIPTION}" \
    -a all -s dir -t deb -v ${PKG_VERSION} -n ${PKG_NAME} $(find {usr/bin,etc/skel} -type f)

fpm --rpm-user root --rpm-group root \
    --description "${PKG_DESCRIPTION}" \
    -a all -s dir -t rpm -v ${PKG_VERSION} -n ${PKG_NAME} $(find {usr/bin,etc/skel} -type f)

