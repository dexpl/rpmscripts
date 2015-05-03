#!/bin/sh

# Builds given rpm spec inside a mock chroot and puts it into an appropriate
# local repository

set -e

# -c remove sources and spec after building src.rpm
# -l call rpmlint
# -L work "locally", don't involve mock at all
# -M do not move the results into repo dir
# -r <chroot> use specified chroot
while getopts ":lLMr:v" Option
do
  case $Option in
    c) cleanup=1 ;;
    l) lint=1 ;;
    L)
			localbuild=1
			echo "Warning: doing local build, any chroot set via command line are ignored" >&2
			echo "Warning: doing local build, won't move results" >&2
			nomove=1
		;;
    M) nomove=1 ;;
    r) chroot="$OPTARG" ;;
		v) verbose=1 ;;
    *)
      echo "Unknown option ${Option} ${OPTARG}, aborting">&2
      exit 1
    ;;
  esac
done

shift $(($OPTIND - 1))

[ -n "${verbose}" ] && set -x

spec="${1}"
case "$(file -b --mime-type "${spec}")" in
	application/x-rpm)
		srcrpm="${spec}"
		if [ -z "${localbuild}" ]; then
			unset spec
		else
			rpm -ihv "${srcrpm}"
			spec="$(rpm -E %{_specdir})/$(rpm -qp --qf '%{name}.spec' ${srcrpm})"
		fi
	;;
	text/plain)
		srcrpm="$(rpm -q --qf '%{name}-%{version}-%{release}\n' --specfile "${spec}" | head -n 1).src.rpm"
	;;
	*)
		echo "${1} is neither an .src.rpm nor a .spec file, aborting" >&2
		exit 1
	;;
esac

srcrpmdir="$(rpm -E %{_srcrpmdir})"

if [ -z "${chroot}" ]; then
# If building inside mock chroot
	if [ -z "{localbuild}" ]; then
		chroot="$(basename $(readlink -f /etc/mock/default.cfg) .cfg)"
		chrootdir="$(mock -p -r "${chroot}")"
# TODO do not hardcode ../result
		resultdir="${chrootdir}../result"
		read chrootname chrootver chrootarch ign <<< ${chroot//-/ }
	else
# We do a local build, so the only possible "chroot" is our current system
		read chrootname chrootver chrootarch <<< $(rpm -q --qf '%{name} %{version} %{arch}' --whatprovides system-release)
		chrootname=${chrootname/-release/}
	fi
fi

# Where to move result (s)rpms
baserepodir=/srv/custom
case "${chrootname}" in
  centos)
    srcrpmdir_moveto="${baserepodir}/${chrootname}/${chrootver}/SRPMS"
# debuginfo rpm path
    debugrpmdir_moveto="${baserepodir}/${chrootname}/${chrootver}/${chrootarch}/debug"
    rpmdir_moveto="${baserepodir}/${chrootname}/${chrootver}/${chrootarch}"
  ;;
  fedora | rfremix)
    srcrpmdir_moveto="${baserepodir}/fedora/${chrootver}/source/SRPMS"
# debuginfo rpm path
    debugrpmdir_moveto="${baserepodir}/fedora/${chrootver}/${chrootarch}/debug"
    rpmdir_moveto="${baserepodir}/fedora/${chrootver}/${chrootarch}/os"
  ;;
esac

[ -n "${spec}" ] && {
	spectool -R -g "${spec}"
	[ -n "${lint}" ] && rpmlint "${spec}"
	rpmbuild -bs "${spec}"
	[ -n "${cleanup}" ] && rpmbuild --clean --rmsource --rmspec --nodeps "${spec}"
	srcrpm="${srcrpmdir}/${srcrpm}"
}
if [ -z "${localbuild}" ]; then
	mock -r "${chroot}" "${srcrpm}"
else
	rpmbuild -bb "${spec}"
fi

[ -z "${nomove}" ] && {
	[ -d "${srcrpmdir_moveto}" -a -d "${debugrpmdir_moveto}" -a -d "${rpmdir_moveto}" ] && \
		find "${resultdir}" \( -name \*.src.rpm -exec mv -vt "${srcrpmdir_moveto}" '{}' + \) \
			-o \( -name '*-debuginfo*.rpm' -exec mv -vt "${debugrpmdir_moveto}" '{}' + \) \
			-o \( -name '*.rpm' -exec mv -vt "${rpmdir_moveto}" '{}' + \)
	refreshcustomrepo 
}
