#!/bin/sh

# Builds a binary rpm package within mock chroot from .src.rpm given
# Usage: ${0} srpm >&2

set -e
[ -n "${DEBUG}" ] && set -x

mockconfdir=/etc/mock

# Displays usage information and exits if $1 is set
usage () {
	echo Help is not yet implemented
	echo
	[ -n "${1}" ] && exit
}

# Echoes $1 to stderr, calls usage() and exits with $2 exit code (1 if omitted)
error_exit () {
	exec 1>&2
	echo ${1:-"Unspecified fatal error occured"}
	echo
	usage
	exit ${2:-1}
}

list_chroots () {
# chroot listing is done in a naive assumption that mock conf dir is always
# /etc/mock and chroot conf file names have <distname>-<releasever>-<arch>.cfg
# format
	find "${mockconfdir}" -name '*-*-*'.cfg -type f -printf '%f\n' | sed 's/\.cfg//' | sort -n
}

# Чего хочется:
# 1) указать, какой chroot использовать
# 3) (когда-нибудь) обрабатывать больше одного .src.rpm за раз
# 4) (когда-нибудь) показать имя и версию и выйти

# Let it be -c aka --chroot to set chroot to build into (optional)
# Let it be -h aka --help to display help (optional; does nothing at this moment)
# Let it be -l aka --list-chroots to list possible chroots (optional)
# Let it be -v aka --version to display name and version than exit (optional; does nothing at this moment)

while getopts ":c:hlv" opt
do
	case ${opt} in
		c )
			chroot=${OPTARG}
		;;
		h )
			show_help=1
		;;
		l )
			ls_chroots=1
		;;
		v )
			echo "-${OPTARG}: unimplemented option"
		;;
		* )
			error_exit "-${OPTARG}: unknown option, exiting"
		;; # Default.
	esac
done

srpms=$@
[ -n "${DEBUG}" ] && echo '$srpms is '"${srpms}"

[ -n  "${show_help}" ] && usage exit
[ -n  "${ls_chroots}" ] && list_chroots && exit
[ -n  "${chroot}" ] && {
  mockopts="-r ${chroot}"
  echo Using chroot ${chroot}
}

srpm=${1}
read srcrpmdir sourcedir specdir rpmdir <<< $(rpm -E %_srcrpmdir -E %_sourcedir -E %_specdir -E %_rpmdir)
# TODO somehow let the user choose which chroot to use
# TODO do not hardcode /var/lib/mock
mockdir="/var/lib/mock/$(basename $(readlink -f "${mockconfdir}"/${chroot:-default}.cfg ) .cfg)/result"

# Build an rpm (or rpms)
mock "${srpm}" || less -F "${mockdir}/build.log"
# ...and move 'em into %_srcrpmdir (.src.rpm) or %_rpmdir (.rpm)
find "${mockdir}" \( -name '*.src.rpm' -exec mv -vt "${srcrpmdir}" '{}' + \) \
	-o \( -name '*.rpm' -exec mv -vt "${rpmdir}" '{}' + \)
