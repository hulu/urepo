This is readme for urepo (universal repository for linux binary packages).

Urepo can host both rpm and deb packages. Nginx is used as web frontend.
Generation of metadata is done by apt-ftparchive for .deb packages and by
createrepo for .rpm packages. File upload can be done using pure http via
browser by using http://urepo.server/ URL or from command line:

curl -s -F dist=centos6 \
    -F branch=stable \
    -F file1=@/path/to/pkg.rpm \
    http://urepo.server/upload

After uploading file is processed automatically via
http://urepo.server/cgi/process-file hook. process-file invokes appropriate
handler according to package file extension.

Another way to upload package is to use urepo-upload.sh utility. It uses
ssh for uploading, after upload is done it triggers file processing via the
same http://urepo.server/cgi/process-file hook.

Drawbacks of current system:
    - no easy way to delete obsolete packages;
    - in order to promote package from testing to stable you need to reupload
      it, should use hard link instead;
    - due to immediate processing single instance of processing code can run
      at a time, this can become bottleneck if uploading would happen often;

Building.

Urepo is build by build-urepo.sh script, .deb package is created. Currently
urepo can be installed only on ubuntu or other debian derivatives.

Urepo-upload is build by build-urepo-upload.sh, both .deb and .rpm packages
are created.
