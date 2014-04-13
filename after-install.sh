#!/bin/bash

set -u

configure_urepo() {
    . /etc/urepo/urepo.conf
    mkdir -p $RPM_REPO_ROOT && cd $RPM_REPO_ROOT
    mkdir -p $(eval "echo $RPM_RELEASES/$RPM_COMPONENTS/$RPM_ARCHITECTURES")
    mkdir $DEB_REPO_ROOT && cd $DEB_REPO_ROOT
    mkdir -p $(eval "echo pool/$DEB_CODENAMES/$DEB_COMPONENTS")
    mkdir -p $(eval "echo dists/$DEB_CODENAMES/$DEB_COMPONENTS/binary-$DEB_ARCHITECTURES")
    for codename in $(eval "echo $DEB_CODENAMES"); do
        for component in $(eval "echo $DEB_COMPONENTS"); do
            pool_dir=pool/$codename/$component
            for arch in $(eval "echo $DEB_ARCHITECTURES"); do
                data_dir=dists/$codename/$component/binary-$arch
                [ -r "$data_dir/Packages" ] || {
                    apt-ftparchive -d $data_dir/.cache --arch ${arch} packages $pool_dir > $data_dir/Packages
                    gzip -c $data_dir/Packages >$data_dir/Packages.gz
                }
            done
        done
        apt-ftparchive \
            -o APT::FTPArchive::Release::Suite="$codename" \
            -o APT::FTPArchive::Release::Codename="$codename" \
            -o APT::FTPArchive::Release::Architectures="$(eval echo $DEB_ARCHITECTURES)" \
            -o APT::FTPArchive::Release::Components="$(eval echo $DEB_COMPONENTS)" \
            release dists/$codename > dists/$codename/Release
    done
    mkdir -p $UREPO_UPLOAD_DIR
    chmod 0733 $UREPO_UPLOAD_DIR
    chown -R www-data:www-data $UREPO_UPLOAD_DIR/..
    host_name=$(hostname -f)
    sed -i -e "s/server_name[^;]*;/server_name ${host_name};/" /etc/urepo/urepo-nginx
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

