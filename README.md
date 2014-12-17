urepo: universal repository for linux binary packages
=======================================

Urepo can host both rpm and deb packages. Nginx is used as a web frontend.
Generation of metadata is done by apt-ftparchive for .deb packages and by
createrepo for .rpm packages. File upload can be done using pure http via
browser by using http://urepo.server/ URL or from command line:

```
curl -X POST -s -F dist=centos6 \
    -F branch=stable \
    -F file1=@/path/to/pkg.rpm \
    http://urepo.server/cgi/process-file
```

The process-file hook invokes the appropriate handler according to package file extension.

Another way to upload a package is to use the urepo-upload.sh utility. It uses
ssh for uploading, after upload is done it triggers file processing via the
same http://urepo.server/cgi/process-file hook.

In order to delete package DELETE request can be used:

```
curl -X DELETE -s -F dist=centos6 \
    -F branch=stable \
    -F file1=@pkg.rpm \
    http://urepo.server/cgi/process-file
```

Drawbacks of current system:
- no support for uploading only signed packages
- no authentication for deleting packages
- in order to promote package from testing to stable you need to reupload
  it, should use hard link instead
- due to immediate processing single instance of processing code can run
  at a time, this can become bottleneck if uploading would happen often

Building.

Urepo is built by running "make pkg", which creates a .deb package.
Currently urepo can be installed only on Ubuntu or other Debian derivatives.

Urepo-upload is build by running build-urepo-upload.sh, which creates both .deb and .rpm packages.
