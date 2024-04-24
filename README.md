urepo: universal repository for linux binary packages
=======================================

Urepo can host both rpm and deb packages. Nginx is used as a web frontend.
Generation of metadata is done by apt-ftparchive for .deb packages and by
createrepo for .rpm packages. File upload can be done using pure HTTP via
browser by using http://urepo.server/ URL or from command line:

```
curl -X POST -s -F dist=centos7 \
    -F branch=stable \
    -F file1=@/path/to/pkg.rpm \
    http://urepo.server/cgi/process-file
```

The process-file hook invokes the appropriate handler according to package file extension.

Another way to upload a package is to use the urepo-upload.sh utility. It uses
SSH for uploading, after upload is done it triggers file processing via the
same http://urepo.server/cgi/process-file hook.

In order to delete package DELETE request can be used:

```
curl -X DELETE -s -F dist=centos7 \
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

### Requirements

#### Package management requirements

First you'll need to install a few packages to correctly build:

```
apt install git build-essential nginx fcgiwrap createrepo
```

#### Install FPM

Urepo requires fpm to run correctly, please follow the installation [instructions](https://fpm.readthedocs.io/en/latest/installation.html) before proceeding.

### Download urepo

Time to download urepo, follow these steps:

```
cd <your location to build>
git clone https://github.com/hulu/urepo.git
cd urepo
```

### Pre-configuration

Now we'll pre-configure your urepo before building the package; open **etc/urepo/urepo.conf**, where you can define:
+ DEB
  + **DEB_CODENAMES**: [Debian](https://en.wikipedia.org/wiki/Debian_version_history)/[Ubuntu](https://en.wikipedia.org/wiki/Ubuntu_(operating_system)#Releases) releases; it can be jessie, stretch, etc ...
  + **DEB_ARCHITECTURES**: default binary [architectures](https://wiki.debian.org/SupportedArchitectures) to support; it can be amd64, i386, etc.
  + **DEB_COMPONENTS**: tweaks of the release; it can be stable, testing, etc.
  * **DEB_CUSTOM_ARCHES**: _optional_ extra architectures to support for specific release(s); not required, should be formatted as a bash dictionary, e.g. `declare -A DEB_CUSTOM_ARCHES=([focal]="arm64")`

+ RPM
  + **RPM_RELEASES**: [CentOS](https://en.wikipedia.org/wiki/CentOS#Versioning_and_releases) releases; it can be centos7, rocky8, etc ...
  * **RPM_ARCHITECTURES**: default binary [architectures](https://fedoraproject.org/wiki/Architectures) to support; it can be x86\_64, aarch64, etc.
  + **RPM_COMPONENTS**: tweaks of the release; it can be stable, testing, etc.
  * **RPM_CUSTOM_ARCHES**: _optional_ extra architectures to support for specific release(s); not required, should be formatted as a bash dictionary, e.g. `declare -A RPM_CUSTOM_ARCHES=([rocky8]="aarch64")`

It's important that you correctly configure this part before the build since the building part will configure the upload page and also the main configuration file **/etc/urepo/urepo.conf**.

We don't cover other parameters since they are more easy to change, for example **UREPO_ROOT** which is the root directory to keep your .deb and .rpm files.

### Let's make

Now you can build your urepo binary as follow:

```
make pkg
```

If all goes well, it should tell you something like this:

```
gcc -Wall -O2 -o extract-post-file extract-post-file.c
mkdir build_2.2.6
cp -r {var,etc} build_2.2.6/
cp extract-post-file build_2.2.6/var/urepo/cgi
cd build_2.2.6 && \
    fpm --deb-user root --deb-group root \
        -d nginx -d fcgiwrap -d createrepo \
        --deb-no-default-config-files \
        --description "Universal repository for Linux binary packages" \
        --license "MIT License" \
        --vendor "Hulu" \
        --maintainer "infra-eng@hulu.com" \
        --url https://github.com/hulu/urepo \
        --after-install ../after-install.sh \
        --before-remove ../before-remove.sh \
        -s dir -t deb -v 2.2.6 -n urepo `find . -type f` && \
    find . ! -name '*.deb' -delete
Created package {:path=>"urepo_2.2.6_amd64.deb"}
```

If you get the following error message:

```
gcc -Wall -O2 -o extract-post-file extract-post-file.c
mkdir build
mkdir: impossible de créer le répertoire « build »: Le fichier existe
makefile:14 : la recette pour la cible « pkg » a échouée
make: *** [pkg] Erreur 1
```

you may have tried to build before installing all the requirements, so clean the mess:

```
make clean
```

Check the requirements above and try again.

### Install urepo.deb

When you have built the urepo.deb package, you can install it:

```
cd build/
dpkg -i urepo_x.y.z_amd64.deb
```

### Check

Now that it's installed, you can check that it's running. Open up **/etc/nginx/sites-enabled/urepo-nginx** and open the **server_name** in your brower, if you see an upload form, then it worked!

## Building urepo-upload

Urepo-upload is build by running build-urepo-upload.sh, which creates both .deb and .rpm packages.

## Add your urepo server to your package manager

### Debian/Ubuntu

Do as follows:

```
echo 'deb [trusted=yes] http://myurepo.server/deb {DEB_CODENAMES} {DEB_COMPONENTS}' > /etc/apt/sources.list.d/myurepo.list
```

Now you can update and list the packages from your own urepo server:

```
apt update
apt list mypackage
```

### CentOS/RedHat

Do as follows where, e.g., DISTRO = "centos7", BRANCH = "testing", ARCHITECTURE = "x86\_64":

```
cat <<EOF > /etc/yum.repos.d/myurepo.list
[myurepo]
name=myurepo
enabled=1
baseurl=http://myurepo.server/rpm/${DISTRO}/${BRANCH}/${ARCHITECTURE}
gpgcheck=0
EOF
```

This should now make it possible to search your own urepo server:

```
yum search mypackage
```

## Known issues / Common mistakes

### Wrong component

```
W: Failed to fetch https://urepo.server/deb/dists/jessie/Release: Unable to find expected entry 'main/binary-amd64/Packages' in Release file (Wrong sources.list entry or malformed file)
E: Some index files failed to download. They have been ignored, or old ones used instead.
```

Please check that the **DEB_COMPONENTS** is the same in your sources.list and in your urepo.conf, there it's **main** but maybe urepo is not configured to work with it.
