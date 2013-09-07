#!/bin/sh

# Just builds srpm package within mock chroot from .spec file given
# Usage: $0 spec >&2

[ $# -eq 1 ] || {
  echo Usage: $0 spec >&2
  exit 1
}

set -e

spec=$1
rpmname=$(rpmspec -q --queryformat '%{name}' --srpm "${spec}")
read srcrpmdir sourcedir <<< $(rpm -E %_srcrpmdir -E %_sourcedir)
# TODO somehow let the user choose which chroot to use
# TODO do not hardcode /var/lib/mock
mockdir="/var/lib/mock/$(basename $(readlink -f /etc/mock/default.cfg ) .cfg)/result"

# Download all the sources/patches if they're missing
spectool -g -R "${spec}"
# ...build srpm (TODO check if done already)
mock --buildsrpm --sources="${sourcedir}" --spec="${spec}"
# ...and move it into %_srcrpmdir
find "${mockdir}" -name "${rpmname}"'*'.src.rpm -type f -exec mv -vt "${srcrpmdir}" '{}' +
