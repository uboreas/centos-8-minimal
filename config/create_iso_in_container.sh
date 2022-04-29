#!/bin/bash -e

echo "Build started at: `date`"

if [ "${1}" == "" ]; then
  CMOUT="CentOS-x86_64-minimal.iso"
else
  CMOUT="${1}"
fi

# Enable reuired repos / modules 
LOCAL_REPO_SETTINGS="--installroot=/root/dtemp/ --releasever=8"
dnf clean all
#dnf --disablerepo '*' --enablerepo extras swap centos-linux-repos centos-stream-repos ${LOCAL_REPO_SETTINGS} -y 
dnf module enable idm:DL1 ${LOCAL_REPO_SETTINGS} -y 
dnf distro-sync ${LOCAL_REPO_SETTINGS} -y

           ./bootstrap.sh clean
CMISO="$1" ./bootstrap.sh step isounpack
           ./bootstrap.sh step createtemplate
           ./bootstrap.sh step collectrpms
           ./bootstrap.sh step collectpymodules
           ./bootstrap.sh step createrepo
           ./bootstrap.sh step createiso

cp ./${CMOUT} /mnt/

echo "Build finished at: `date`"
