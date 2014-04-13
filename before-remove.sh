#!/bin/bash

deb_remove() {
    rm -f /etc/nginx/sites-enabled/repo-nginx
    /etc/init.d/nginx restart
}

deb_upgrade() {
    echo "script: before-remove, action: deb upgrade, nothing to do"
}

rpm_remove() {
    echo "rpm remove not supported"
}

rpm_upgrade() {
    echo "rpm upgrade not supported"
}

case ${1:-} in
    remove|purge) deb_remove ;;
    upgrade) deb_upgrade ;;
    0) rpm_remove ;;
    1) rpm_upgrade ;;
esac

