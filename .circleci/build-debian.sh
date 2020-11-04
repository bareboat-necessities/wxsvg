#!/usr/bin/env bash

#
# Build for Debian in a docker container
#

# bailout on errors and echo commands.
set -xe

DOCKER_SOCK="unix:///var/run/docker.sock"

echo "DOCKER_OPTS=\"-H tcp://127.0.0.1:2375 -H $DOCKER_SOCK -s overlay2\"" | sudo tee /etc/default/docker > /dev/null
sudo service docker restart
sleep 5;

if [ "$EMU" = "on" ]; then
  if [ "$CONTAINER_DISTRO" = "raspbian" ]; then
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
  else
      docker run --rm --privileged --security-opt="seccomp=unconfined" --cap-add=ALL multiarch/qemu-user-static --reset --credential yes --persistent yes
  fi
fi

WORK_DIR=$(pwd):/ci-source

docker run --privileged --security-opt="seccomp=unconfined" --cap-add=ALL -d -ti -e "container=docker"  -v $WORK_DIR:rw $DOCKER_IMAGE /bin/bash
DOCKER_CONTAINER_ID=$(docker ps --last 4 | grep $CONTAINER_DISTRO | awk '{print $1}')

docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get update
docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y install apt-transport-https wget curl gnupg2

docker exec --privileged -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
  "wget -q 'https://dl.cloudsmith.io/public/bbn-projects/bbn-repo/cfg/gpg/gpg.070C975769B2A67A.key' -O- | apt-key add -"
docker exec --privileged -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
  "wget -q 'https://dl.cloudsmith.io/public/bbn-projects/bbn-repo/cfg/setup/config.deb.txt?distro=${PKG_DISTRO}&codename=${PKG_RELEASE}' -O- | tee -a /etc/apt/sources.list"

docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get update
docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y install dpkg-dev debhelper devscripts equivs pkg-config apt-utils fakeroot
docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y install build-essential dh-exec \
 libavcodec-dev        \
 libavformat-dev       \
 libavutil-dev         \
 libexif-dev           \
 libexpat-dev          \
 libpango1.0-dev       \
 libswscale-dev        \
 libwxgtk3.1-gtk3-dev  \
 pkg-config

#docker exec --privileged -ti $DOCKER_CONTAINER_ID apt-get -y upgrade
docker exec --privileged -ti $DOCKER_CONTAINER_ID ldconfig

docker exec --privileged -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
    "update-alternatives --set fakeroot /usr/bin/fakeroot-tcp; cd ci-source; mkdir SVG; cd SVG; wget http://deb.debian.org/debian/pool/main/w/wxsvg/wxsvg_1.5.22+dfsg.1.orig.tar.xz; xzcat wxsvg_1.5.22+dfsg.1.orig.tar.xz | tar xvf -; cd wxsvg_1.5.22/; cp -r ../debian . ; dpkg-buildpackage -b -uc -us -j2; dpkg -i ../*.deb; cd ../../"

docker exec --privileged -ti $DOCKER_CONTAINER_ID /bin/bash -xec "mv SVG/*.deb ci-source/dist"

find dist -name \*.\*$EXT

echo "Stopping"
docker ps -a
docker stop $DOCKER_CONTAINER_ID
docker rm -v $DOCKER_CONTAINER_ID
