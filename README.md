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
    -F file1=pkg.rpm \
    http://urepo.server/cgi/process-file
```

Drawbacks of current system:
- no support for uploading only signed packages
- no authentication for deleting packages
- in order to promote package from testing to stable you need to reupload
  it, should use hard link instead
- due to immediate processing single instance of processing code can run
  at a time, this can become bottleneck if uploading would happen often

## Building urepo

Currently urepo can be installed **only** on Ubuntu or other Debian derivatives.
Urepo build relies on the ```dpkg-deb``` option ```--root-owner-group``` and will fail if your version of ```dpkg-deb``` doesn't support this option.

### Requirements

#### Package management requirements

First you'll need to install a few packages to correctly build:

```
apt install git build-essential nginx fcgiwrap createrepo
```

### Download urepo

Time to download urepo, follow these steps:

```
cd <your location to build>
git clone https://github.com/hulu/urepo.git
cd urepo
```

### Pre-configuration

Now we'll pre-configure your urepo before to build it, open **etc/urepo/urepo.conf**, you can define:
+ DEB
  + **DEB_CODENAMES**: [Debian](https://en.wikipedia.org/wiki/Debian_version_history)/[Ubuntu](https://en.wikipedia.org/wiki/Ubuntu_(operating_system)#Releases) releases; it can be, jessie, stretch, etc ...
  + **DEB_COMPONENTS**: tweaks of the release; it can be stable, testing, etc ...

+ RPM
  + **RPM_RELEASES**: [CentOS](https://en.wikipedia.org/wiki/CentOS#Versioning_and_releases) releases; it can be centos5, centos6, etc ...
  + **RPM_COMPONENTS**: tweaks of the release; it can be stable, testing, etc ...

It's important that you correctly configure this part before to build since the building part will configure the upload page and also the main configuration file **/etc/urepo/urepo.conf**.

We don't cover other parameters since they are more easy to change, for example **UREPO_ROOT** which is the root directory to keep your .deb and .rpm.

### Let's make

Now you can build your urepo as follow:

```
make
```

If all goes well, it should tell you something like this:

```
gcc -Wall -O2 -o extract-post-file extract-post-file.c
test/run-test.sh
001-1kb-test ok
002-empty-test ok
003-text-test ok
004-1kb-text-test ok
005-text-1kb-test ok
007-1kb-field-test ok
008-field-1kb-field-test ok
009-1kb-field-text-test ok
010-field-1kb-field-text-field-test ok
Summary: 9 tests passed, 0 tests failed
mkdir -p build
rm -rf build/*
cp -r {var,etc} build/
cp -r DEBIAN.urepo build/DEBIAN
cp extract-post-file build/var/urepo/cgi
chmod -R go-w build
. <(grep -E "^(Package|Version|Architecture):" build/DEBIAN/control |sed -e 's/: \(.*\)/="\1"/') && \
dpkg-deb --root-owner-group -b ./build ${Package}_${Version}_${Architecture}.deb
dpkg-deb: building package 'urepo' in 'urepo_2.2.3_amd64.deb'.
```

If you have the following error message:

```
gcc -Wall -O2 -o extract-post-file extract-post-file.c
mkdir build
mkdir: impossible de créer le répertoire « build »: Le fichier existe
makefile:14 : la recette pour la cible « pkg » a échouée
make: *** [pkg] Erreur 1
```

It's just that you went ahead and tried to build before to install all requirements, so clean the mess:

```
make clean
```

Check the requirements above and try again.

### Install urepo.deb

You have built the urepo.deb package, you can install it:

```
cd build/
dpkg -i urepo_x.y.z_amd64.deb
```

### Check

Now that it's installed, you can check that it's running. Open up **/etc/nginx/sites-enabled/urepo-nginx** and open the **server_name** in your brower, if you see an upload form, then it works !

## Building urepo-upload

Urepo-upload is build by running build-urepo-upload.sh, which creates both .deb and .rpm packages.

## Add your urepo server to your package manager

### Debian/Ubuntu

Do as follow:

```
echo 'deb [trusted=yes] http://myurepo.server/deb {DEB_CODENAMES} {DEB_COMPONENTS}' > /etc/apt/sources.list.d/myurepo.list
```

Now you can update and list the packages from you own urepo server:

```
apt update
grep ^Package: /var/lib/apt/lists/myurepo_*_Packages
```

### CentOS

*work in progress*

## Known issues / Common mistakes

### Wrong component

```
W: Failed to fetch https://urepo.server/deb/dists/jessie/Release: Unable to find expected entry 'main/binary-amd64/Packages' in Release file (Wrong sources.list entry or malformed file)
E: Some index files failed to download. They have been ignored, or old ones used instead.
```

Please check that the **DEB_COMPONENTS** is the same in your sources.list and in your urepo.conf, there it's **main** but maybe urepo is not configured to work with it.
