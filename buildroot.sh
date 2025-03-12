#!/bin/bash

br_patch=`ls *.patch --sort=time | head -n 1`

if [ -z "$br_patch" ]; then
	echo "Error: buildroot patch do not exist"
	exit 1
fi

version=$(basename $br_patch .patch)

rm -rf buildroot buildroot-${version}

export GIT_SSL_NO_VERIFY=1

git clone https://gitlab.com/buildroot.org/buildroot.git buildroot-${version}

git -C buildroot-${version} checkout ${version}

patch --no-backup-if-mismatch -d buildroot-${version} -N -r /dev/null -p1 < $br_patch

mv buildroot-${version} buildroot
