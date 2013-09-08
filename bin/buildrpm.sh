#!/bin/bash

# Build a binary rpm package within mock chroot from .src.rpm given
# Usage: ${0} srpm >&2

# TODO:
# 1) make a library for common functions
# 3) (some day) process more than one .src.rpm at once (man mockchain?)
# 4) (some day) show name and version and exit

. $(dirname $0)/../lib/rpmscripts_functions

while getopts ":c:hlv" opt
do
	case ${opt} in
		c )
			chroot=${OPTARG}
		;;
		h )
			usage
			exit
		;;
		l )
# Not listing chroots right here because it would break the logic of -h (just show usage info and exit)
			ls_chroots=1
		;;
		v )
			echo "-${OPTARG}: unimplemented option"
		;;
		\: )
			error_exit "-${OPTARG}: option requires an argument"
		;; # Default.
		* )
			error_exit "-${OPTARG}: unknown option, exiting"
		;; # Default.
	esac
done

shift $((${OPTIND} - 1))

srpms=$@

[ -n  "${ls_chroots}" ] && list_chroots && exit

[ -n "${srpms}" ] || error_exit "No source RPM(s) specified"
[ -n "${RPMSCRIPTS_DEBUG}" ] && echo '$srpms is '"${srpms}"

[ -n  "${chroot}" ] && {
  mockopts="-r ${chroot}"
  echo Using chroot ${chroot}
}

srpm=${1}
# TODO do not hardcode /var/lib/mock
mockdir="/var/lib/mock/${chroot:-$(basename $(readlink -f "${mockdefaultchroot}") .cfg)}/result"

# Build an rpm (or rpms)
mock ${mockopts} "${srpm}" || less -F "${mockdir}/build.log"
# ...and move 'em into %_srcrpmdir (.src.rpm) or %_rpmdir (.rpm)
find "${mockdir}" \( -name '*.src.rpm' -exec mv -vt "${srcrpmdir}" '{}' + \) \
	-o \( -name '*.rpm' -exec mv -vt "${rpmdir}" '{}' + \)
