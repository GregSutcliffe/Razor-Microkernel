#!/bin/bash

# Quick script to run all the required build steps. Options:
#
# buildiso.sh [-p] isoname [--scp]
#
# -p    - build prod instead of debug image
# --scp - copy to my foreman instance's tftp dir

set -e

# Cleanup old builds
rm build-files/*gz

# Build prod or debug overlay
if [ "$1" == "-p" ] ; then
  ./build-bundle-file.sh -r -b additional-build-files/builtin-extensions.lst -m additional-build-files/mirror-extensions.lst -p
  shift
else
  ./build-bundle-file.sh -r -b additional-build-files/builtin-extensions.lst -m additional-build-files/mirror-extensions.lst -d -t test1234
fi

# Build iso
sudo rm -rf iso && mkdir iso
cd iso
tar xvzf ../build-files/*gz
sudo ./build_initial_directories.sh
sudo ./rebuild_iso.sh $1

# copy to foremanvirt
if [ "$2" == "--scp" ] ; then
  scp rz_mk_*$1*.iso fv:/srv/tftp/boot/foreman.iso
  scp newiso/boot/vmlinuz newiso/boot/core.gz fv:/srv/tftp/boot/
fi
