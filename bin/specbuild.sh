#!/bin/sh

# Builds given .src.rpm or an rpm spec inside a mock chroot and puts it into an
# appropriate local repository

#Локальная сборка: переместить результат из %{_rpmdir}/$(arch) и %{_srcrpmdir} в репы — разные для %{name}.rpm, %{name}-debuginfo.rpm и %{name}.src.rpm. Учесть, что .noarch кладется в %{_rpmdir}/noarch. Можно ли как-то сказать rpmbuild'у, куда складывать результат? Теоретически, да — см. %_rpmfilename. ПРАКТИЧЕСКИ ДА — см. %_rpmdir!
#Сборка внутри mock chroot: mktemp'нуть временный каталог, указать его mock'у как resultdir, переместить результат из него в репы (см. выше).
#
#Т. е. все _предельно_просто_: mktemp'аем временный каталог, говорим, чтобы результаты шли в него, находим в нем .rpm'ки и раскладываем их как нужно (последнее _уже_ реализовано, осталось "намекнуть" про каталог). Единственный неочевидный момент — архитектура.

_cleanup() {
	[ -d "${resultdir}" ] && rm -r "${resultdir}"
}

_full_cleanup() {
 [ -f "${spec}" ] && rpmbuild --clean --rmsource --rmspec --nodeps "${spec}"
 _cleanup
}

trap _cleanup EXIT HUP INT QUIT ABRT
set -e

# Where to move result (s)rpms
baserepodir=/srv/custom

## Echo a warning if $1 is not a directory
#_check_dir() {
#	[ -d "${1}" ] || {
#		echo "Warning: ${1} is not a directory, results (if any) won't be moved" >&2
#		return 1
#	}
#}

# Echo a warning if any of $@ is not a directory
_check_dirs() {
	for dir in $@ ; do
		[ -d "${dir}" ] || {
			echo "Warning: ${dir} is not a directory, results (if any) won't be moved" >&2
			return 1
	}
	done
}

# -c remove sources and spec after building src.rpm
# -l call rpmlint
# -L work "locally", don't involve mock at all
# -M do not move the results into repo dir
# -r <chroot> use specified chroot
while getopts ":lLMr:v" Option
do
  case $Option in
    c) cleanup=1
			trap _full_cleanup EXIT
		;;
    l) lint=1 ;;
    L)
			localbuild=1
			echo "Warning: doing local build, any chroot set via command line are ignored" >&2
			echo "Warning: doing local build, won't move results" >&2
			unset baserepodir
		;;
    M) unset baserepodir ;;
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

[ -n "${1}" ] && spec="${1}" || {
	echo "Error: no source specified" >&2
	exit 1
}

case "$(file -b --mime-type "${spec}")" in
	application/x-rpm) : ;;
	text/plain)
# If $1 is a .spec file build an .src.rpm
		spectool -R -g "${spec}"
		rpmbuild -bs "${spec}"
#		[ -n "${cleanup}" ] && rpmbuild --clean --rmsource --rmspec --nodeps "${spec}"
		spec="$(rpm -E %{_srcrpmdir})/$(rpm -q --qf '%{name}-%{version}-%{release}\n' --specfile "${spec}" | head -n 1).src.rpm"
	;;
	*)
		echo "${1} is neither an .src.rpm nor a .spec file, aborting" >&2
		exit 1
	;;
esac

[ -n "${lint}" ] && rpmlint "${spec}"

# TODO check if chroot set inside checking for local build
if [ -n "${chroot}" ]; then
	read targetname targetver targetarch ign <<< ${chroot//-/ }
else
	if [ -n "${localbuild}" ]; then
# We do a local build, so the only possible "chroot" is our current system
		read targetname targetver targetarch <<< $(rpm -q --qf '%{name} %{version} %{arch}' --whatprovides system-release)
		targetname=${targetname/-release/}
	else
		mockconfig="$(basename $(readlink -f /etc/mock/default.cfg) .cfg)"
		read targetname targetver targetarch ign <<< ${mockconfig//-/ }
	fi
fi

#if [ -d "${baserepodir}" ]; then
#	resultdir="$(mktemp -d)"
#else
#	echo "Warning: ${baserepodir} is not a directory, won't move result" >&2
#fi
_check_dirs "${baserepodir}" && resultdir="$(mktemp -d)"

# Determine the build command
if [ -n "${localbuild}" ]; then
	buildcommand="rpmbuild"
# TODO FIXME setarch is likely not the way, maybe -D '_target_cpu' should be used instead
	[ -n "${targetarch}" -a "${targetarch}" != "$(arch)" ] && buildcommand="setarch ${targetarch} ${buildcommand}"
#	[ -d "${resultdir}" ] && buildcommand="${buildcommand} -D '%_rpmdir ${resultdir}'"
	_check_dirs "${resultdir}" && buildcommand="${buildcommand} -D '%_rpmdir ${resultdir}'"
else
#	buildcommand="mock"
#	[ -n "${chroot}" ] && buildcommand="${buildcommand} -r ${chroot}"
	buildcommand="mock -r ${chroot:-${mockconfig}}"
#	[ -d "${resultdir}" ] && buildcommand="${buildcommand} --resultdir=${resultdir}"
	_check_dirs "${resultdir}" && buildcommand="${buildcommand} --resultdir=${resultdir}"
fi

${buildcommand} "${spec}"

# If nomove was not set there's no resultdir
# If there was a fatal error while making resultdir, we never get to this point
_check_dirs "${resultdir}" && {

	case "${targetname}" in
		centos)
			srcrpmdir_moveto="${baserepodir}/${targetname}/${targetver}/SRPMS"
# debuginfo rpm path
			debugrpmdir_moveto="${baserepodir}/${targetname}/${targetver}/${targetarch}/debug"
			rpmdir_moveto="${baserepodir}/${targetname}/${targetver}/${targetarch}"
		;;
		fedora | rfremix)
			srcrpmdir_moveto="${baserepodir}/fedora/${targetver}/source/SRPMS"
# debuginfo rpm path
			debugrpmdir_moveto="${baserepodir}/fedora/${targetver}/${targetarch}/debug"
			rpmdir_moveto="${baserepodir}/fedora/${targetver}/${targetarch}/os"
		;;
	esac

#	[ -d "${srcrpmdir_moveto}" -a -d "${debugrpmdir_moveto}" -a -d "${rpmdir_moveto}" ] && \
#		find "${resultdir}" \( -name \*.src.rpm -exec mv -vt "${srcrpmdir_moveto}" '{}' + \) \
#			-o \( -name '*-debuginfo*.rpm' -exec mv -vt "${debugrpmdir_moveto}" '{}' + \) \
#			-o \( -name '*.rpm' -exec mv -vt "${rpmdir_moveto}" '{}' + \)
#	refreshcustomrepo
	mv="mv"
	[ -n "${verbose}" ] && mv="${mv} -vt" || mv="${mv} -t"
	_check_dirs "${srcrpmdir_moveto}" "${debugrpmdir_moveto}" "${rpmdir_moveto}" ] && \
		find "${resultdir}" \( -name \*.src.rpm -exec ${mv} "${srcrpmdir_moveto}" '{}' + \) \
			-o \( -name '*-debuginfo*.rpm' -exec ${mv} "${debugrpmdir_moveto}" '{}' + \) \
			-o \( -name '*.rpm' -exec ${mv} "${rpmdir_moveto}" '{}' + \) && refreshcustomrepo
	rm -r "${resultdir}"
}
