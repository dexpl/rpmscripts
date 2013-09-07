#!/bin/sh

# Builds a binary rpm package within mock chroot from .src.rpm given
# Usage: ${0} srpm >&2

set -e
[ -n "${DEBUG}" ] && set -x

usage () {
	echo Help is not yet implemented
	echo
}

# Чего хочется:
# 1) указать, какой chroot использовать
# 2) перечислить доступные chroot'ы и выйти
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
			echo "-${OPTARG}: unknown option, exiting" >&2
			echo >&2
			usage >&2
			exit 1
		;; # Default.
	esac
done

srpms=$@
[ -n "${DEBUG}" ] && echo '$srpms is '"${srpms}"

[ -n  "${show_help}" ] && {
	usage
	exit
}
[ -n  "${ls_chroots}" ] && echo 'Listing chroots (not impl. yet)'
[ -n  "${chroot}" ] && {
  mockopts="-r ${chroot}"
  echo Using chroot ${chroot}
}
echo Still here
exit 0
srpm=${1}
read srcrpmdir sourcedir specdir rpmdir <<< $(rpm -E %_srcrpmdir -E %_sourcedir -E %_specdir -E %_rpmdir)
# TODO somehow let the user choose which chroot to use
# TODO do not hardcode /var/lib/mock
mockdir="/var/lib/mock/$(basename $(readlink -f /etc/mock/default.cfg ) .cfg)/result"

# Build an rpm (or rpms)
mock "${srpm}" || less -F "${mockdir}/build.log"
# ...and move 'em into %_srcrpmdir (.src.rpm) or %_rpmdir (.rpm)
find "${mockdir}" \( -name '*.src.rpm' -exec mv -vt "${srcrpmdir}" '{}' + \) \
	-o \( -name '*.rpm' -exec mv -vt "${rpmdir}" '{}' + \)
