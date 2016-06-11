#!/bin/bash

deb_remove() {
    rm -f /etc/nginx/sites-enabled/repo-nginx
    /etc/init.d/nginx restart
}

deb_upgrade() {
    return 0
}

case ${1:-} in
    remove|purge) deb_remove ;;
    upgrade) deb_upgrade ;;
esac
