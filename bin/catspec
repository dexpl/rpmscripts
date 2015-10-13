#!/bin/sh

usage() {
	local myName=$(basename "${0}")
	echo ${myName}: echo to STDOUT a .spec of a given rpm package
	echo
	echo Usage: ${myName} rpm
	echo
}

[ $# -ne 1 ] && {
	usage >&2
	exit 1
}

rpm=${1}

yumdownloader --debuglevel 0 --source --urls "${rpm}" | wget -i - -O - -q | rpm2cpio | cpio -i --quiet --to-stdout "*.spec" | ${PAGER-less}
