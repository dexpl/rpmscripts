#!/bin/sh

# Builds given .src.rpm or an rpm spec inside a mock chroot and puts it into an
# appropriate local repository

# TODO consider arch while doing local builds

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
      echo "Unknown option -${OPTARG}, aborting" >&2
      exit 1
    ;;
  esac
done

shift $(($OPTIND - 1))

[ -n "${verbose}" ] && set -x

[ -n "${1}" ] && srcrpm="${1}" || {
	echo "Error: no source specified" >&2
	exit 1
}

case "$(file -b --mime-type "${srcrpm}")" in
	application/x-rpm) : ;;
	text/plain)
# If $1 is a .spec file build an .src.rpm
		spectool -R -g "${srcrpm}"
		rpmbuild -bs "${srcrpm}"
		[ -n "${cleanup}" ] && rpmbuild --clean --rmsource --rmspec --nodeps "${srcrpm}"
		srcrpm="$(rpm -E %{_srcrpmdir})/$(rpm -q --qf '%{name}-%{version}-%{release}\n' --specfile "${srcrpm}" | head -n 1).src.rpm"
	;;
	*)
		echo "${1} is neither an .src.rpm nor a .spec file, aborting" >&2
		exit 1
	;;
esac

[ -n "${lint}" ] && rpmlint "${srcrpm}"

#if [ -z "${localbuild}" ]; then
#	[ -z "${chroot}" ] && chroot="$(basename $(readlink -f /etc/mock/default.cfg) .cfg)"
#	mock -r "${chroot}" "${srcrpm}"
#else
#	rpmbuild --rebuild "${srcrpm}"
#fi

# Determine the build command
read resultname resultver resultarch ign <<< ${chroot//-/ }
if [ -n "${localbuild}" ]; then
	buildcommand="rpmbuild"
#	[ -n "${resultarch}" -a "${resultarch}" != "$(arch)" -a "${resultarch}" != "noarch" ] && buildcommand="setarch ${resultarch} ${buildcommand}"
#TODO FIXME setarch is likely not the way, maybe -D '_target_cpu' should be used instead
	[ -n "${resultarch}" -a "${resultarch}" != "$(arch)" ] && buildcommand="setarch ${resultarch} ${buildcommand}"
else
	buildcommand="mock"
	[ -n "${chroot}" ] && buildcommand="${buildcommand} -r ${chroot}"
fi

echo ${buildcommand} "${srcrpm}"
exit 0

[ -z "${nomove}" ] && {
# Where to move result (s)rpms
	baserepodir=/srv/custom

	if [ -z "{localbuild}" ]; then
# If building inside mock chroot
# TODO do not hardcode ../result
		chrootdir="$(mock -p -r "${chroot}")"
		resultdir="${chrootdir}../result"
		read resultname resultver resultarch ign <<< ${chroot//-/ }
	else
# We do a local build, so the only possible "chroot" is our current system
		read resultname resultver resultarch <<< $(rpm -q --qf '%{name} %{version} %{arch}' --whatprovides system-release)
		resultname=${resultname/-release/}
	fi

	case "${resultname}" in
		centos)
			srcrpmdir_moveto="${baserepodir}/${resultname}/${resultver}/SRPMS"
# debuginfo rpm path
			debugrpmdir_moveto="${baserepodir}/${resultname}/${resultver}/${resultarch}/debug"
			rpmdir_moveto="${baserepodir}/${resultname}/${resultver}/${resultarch}"
		;;
		fedora | rfremix)
			srcrpmdir_moveto="${baserepodir}/fedora/${resultver}/source/SRPMS"
# debuginfo rpm path
			debugrpmdir_moveto="${baserepodir}/fedora/${resultver}/${resultarch}/debug"
			rpmdir_moveto="${baserepodir}/fedora/${resultver}/${resultarch}/os"
		;;
	esac

	[ -d "${srcrpmdir_moveto}" -a -d "${debugrpmdir_moveto}" -a -d "${rpmdir_moveto}" ] && \
		find "${resultdir}" \( -name \*.src.rpm -exec mv -vt "${srcrpmdir_moveto}" '{}' + \) \
			-o \( -name '*-debuginfo*.rpm' -exec mv -vt "${debugrpmdir_moveto}" '{}' + \) \
			-o \( -name '*.rpm' -exec mv -vt "${rpmdir_moveto}" '{}' + \)
	refreshcustomrepo 
}
