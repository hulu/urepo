#!/bin/bash
set -u -e

BASENAME=$(basename $0)
CONFIGS="$HOME/.${BASENAME}.conf /etc/skel/.${BASENAME}.conf"

usage() {
    echo "Usage: ${BASENAME} -d DIST -b BRANCH pkg_path"
    echo "       DIST should be name of distribution supported on your repository (e.g centos6, precise etc)"
    echo "       BRANCH should be stable, testing or anything else supported on your repository"
    echo
    echo "       This utility uses configuration file .${BASENAME}.conf. It looks"
    echo "       for it in home directory and if not found in /etc/skel/."
    echo "       Configuration file should define following environment variables:"
    echo "       UREPO_SERVER - name or ip address of server where we want to upload packages (via ssh)"
    echo "       UREPO_UPLOAD_DIR - location of upload dir on server"
    exit
}

trap 'usage' ERR

load_config() {
    for config in $CONFIGS; do
        [ -r $config ] && . $config && return
    done
    echo "Couldn't find config file"
    usage
}

load_config

while [ -n "${1:-}" ]; do
    case $1 in
        -d) shift && dist=$1 && shift ;;
        -b) shift && branch=$1 && shift ;;
        *) pkg_path=$1 && shift ;;
    esac
done

pkg_name=$(basename $pkg_path)
cat $pkg_path |ssh $UREPO_SERVER "cd $UREPO_UPLOAD_DIR && \
    cat - >$pkg_name && \
    curl -s -F dist=$dist -F branch=$branch -F file1.name=$pkg_name -F file1.path=$UREPO_UPLOAD_DIR/$pkg_name http://127.0.0.1/cgi/process-file"
exit $?
