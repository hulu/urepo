#!/bin/bash

set -u

# let's load urepo config file
. /etc/urepo/urepo.conf
# this variable would contain json for the page, showing upload form
# json would contain entries like: release_name: [branch_name1, branch_name2, ...]
data=""
# let's create rpm directory hierarchy
mkdir -p $RPM_REPO_ROOT && chmod -R +r $RPM_REPO_ROOT
for release in $RPM_RELEASES; do
    options=""
    for component in $RPM_COMPONENTS; do
        options+="${options:+, }\"$component\""
        for arch in $RPM_ARCHITECTURES; do
            dir="$RPM_REPO_ROOT/$release/$component/$arch"
            mkdir -p "$dir"
            createrepo -q -c $dir/.cache $dir
        done
    done
    data+="${data:+, }$release: [$options]"
done
# let's create deb directory hierarchy
mkdir -p $DEB_REPO_ROOT && cd $DEB_REPO_ROOT && chmod -R +r .
for dist in $DEB_CODENAMES; do
    options=""
    for branch in $DEB_COMPONENTS; do
        options+="${options:+, }\"$branch\""
        pool_dir=pool/$dist/$branch
        mkdir -p $pool_dir
        for arch in $DEB_ARCHITECTURES; do
            mkdir -p dists/$dist/$branch/binary-$arch
        done
    done
    . $UREPO_ROOT/cgi/run-apt-ftparchive
    data+=", $dist: [$options]"
done
# let's create directory where files would be uploaded
mkdir -p $UREPO_UPLOAD_DIR
# this directory should be writeable by everybody (for ssh uploads)
# but readable only by owner for security
# security is rather weak, if one user would know name of the file other
# user is uploading he still would be able to change content of this file
# since urepo is not working as root not much can be done here
chmod 0733 $UREPO_UPLOAD_DIR
# let's update file ownership according to user we are working as
chown -R www-data:www-data $UREPO_ROOT
mkdir -p $(dirname $UREPO_LOG)
chown -R www-data:www-data $(dirname $UREPO_LOG)
# now let's set hostname in nginx config
host_name=$(hostname -f)
sed -i -e "s/server_name[^;]*;/server_name ${host_name};/" /etc/urepo/urepo-nginx
# and insert json for upload form generation
sed -i -e "s/\(var data = {\).*\(};\)/\1$data\2/" $UREPO_ROOT/index.html
# let's enable urepo nginx config
rm -f /etc/nginx/sites-enabled/default
ln -nsf /etc/urepo/urepo-nginx /etc/nginx/sites-enabled/urepo-nginx
# and restart nginx
/etc/init.d/nginx restart
