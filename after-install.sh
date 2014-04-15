#!/bin/bash

set -u

configure_urepo() {
    . /etc/urepo/urepo.conf
    data=""
    mkdir -p $RPM_REPO_ROOT && cd $RPM_REPO_ROOT
    for release in $RPM_RELEASES; do
        options=""
        for component in $RPM_COMPONENTS; do
            options+="${options:+, }\"$component\""
            for arch in $RPM_ARCHITECTURES; do
                mkdir -p "$release/$component/$arch"
            done
        done
        data+="${data:+, }$release: [$options]"
    done
    mkdir $DEB_REPO_ROOT && cd $DEB_REPO_ROOT
    for codename in $DEB_CODENAMES; do
        options=""
        for component in $DEB_COMPONENTS; do
            options+="${options:+, }\"$component\""
            pool_dir=pool/$codename/$component
            mkdir -p $pool_dir
            for arch in $DEB_ARCHITECTURES; do
                data_dir=dists/$codename/$component/binary-$arch
                mkdir -p $data_dir
                [ -r "$data_dir/Packages" ] || {
                    apt-ftparchive -d $data_dir/.cache --arch ${arch} packages $pool_dir > $data_dir/Packages
                    gzip -c $data_dir/Packages >$data_dir/Packages.gz
                }
            done
        done
        apt-ftparchive \
            -o APT::FTPArchive::Release::Suite="$codename" \
            -o APT::FTPArchive::Release::Codename="$codename" \
            -o APT::FTPArchive::Release::Architectures="$DEB_ARCHITECTURES" \
            -o APT::FTPArchive::Release::Components="$DEB_COMPONENTS" \
            release dists/$codename > dists/$codename/Release
        data+=", $codename: [$options]"
    done
    mkdir -p $UREPO_UPLOAD_DIR
    chmod 0733 $UREPO_UPLOAD_DIR
    chown -R www-data:www-data $UREPO_UPLOAD_DIR/..
    host_name=$(hostname -f)
    sed -i -e "s/server_name[^;]*;/server_name ${host_name};/" /etc/urepo/urepo-nginx
    sed -i -e "s/\(var data = {\).*\(};\)/\1$data\2/" $UREPO_ROOT/index.html
    ln -nsf /etc/urepo/urepo-nginx /etc/nginx/sites-enabled/urepo-nginx
    /etc/init.d/nginx restart
}

deb_install() {
    configure_urepo
}

rpm_install() {
    echo "rpm install not supported"
}

deb_upgrade() {
    configure_urepo
}

rpm_upgrade() {
    echo "rpm upgrade not supported"
}

case ${1:-} in
    configure)
        if [ -z "${2:-}" ] ; then
            deb_install
        else
            deb_upgrade
        fi
        ;;
    1) rpm_install ;;
    2) rpm_upgrade ;;
esac

