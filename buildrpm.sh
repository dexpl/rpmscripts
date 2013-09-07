#!/bin/sh

# Builds a binary rpm package within mock chroot from .src.rpm given
# Usage: $0 srpm >&2

[ $# -eq 1 ] || {
  echo Usage: $0 srpm >&2
  exit 1
}

set -e
#set -x

srpm=$1
read srcrpmdir sourcedir specdir rpmdir <<< $(rpm -E %_srcrpmdir -E %_sourcedir -E %_specdir -E %_rpmdir)
# TODO somehow let the user choose which chroot to use
# TODO do not hardcode /var/lib/mock
mockdir="/var/lib/mock/$(basename $(readlink -f /etc/mock/default.cfg ) .cfg)/result"

# Build an rpm (or rpms)
mock "${srpm}" || less -F "${mockdir}/build.log"
# ...and move 'em into %_srcrpmdir (.src.rpm) or %_rpmdir (.rpm)
find "${mockdir}" \( -name '*.src.rpm' -exec mv -vt "${srcrpmdir}" '{}' + \) \
  -o \( -name '*.rpm' -exec mv -vt "${rpmdir}" '{}' + \)
