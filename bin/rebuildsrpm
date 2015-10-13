#!/bin/bash
#!/bin/sh -x

# TODO getopt
[ $# -lt 2 ] && {
	echo "Usage:" >&2
	echo " $0 <mock-chroot> <fedora-release> <rpm-name>" >&2
	echo or >&2
	echo " $0 <mock-chroot> <rpm-name>" >&2
	exit 1
}

mock_chroot=$1
if [ $# -eq 3 ]; then
	fedora_release=$2
	rpm_name=$3
else
	rpm_name=$2
fi
dist_tag=$(mock -q -r $mock_chroot --chroot "rpm -E '%dist'")

# TODO optionalize
mock_chroot_dir=/var/lib/mock/$mock_chroot
mock_result_dir=${mock_chroot_dir}/result
read srpm_dir source_dir spec_dir rpm_dir <<< $(rpm -E %_srcrpmdir -E %_sourcedir -E %_specdir -E %_rpmdir)

if [ -f $rpm_name ]; then
	srpm=$rpm_name
else
	if [ -f $srpm_dir/$rpm_name ]; then
		srpm=$srpm_dir/$rpm_name
	else
		if echo "$rpm_name" | grep -qF '://' ; then
			wget -ct0 -P $srpm_dir $rpm_name || exit $?
			srpm=$srpm_dir/$(basename $rpm_name)
		else
			srpm_file_name=$(repoquery --releasever $fedora_release --source $rpm_name)
			yumdownloader --releasever $fedora_release --source --destdir $srpm_dir $rpm_name || exit $?
			srpm=$srpm_dir/$srpm_file_name
		fi
	fi
fi
srpm_name=$(rpm -qp --qf '%{name}' $srpm)
if echo $srpm | grep -qF $dist_tag ; then
# We have already got .src.rpm for target distro
	new_srpm_name=$srpm
else
	spec=$spec_dir/$(rpm -qpl $srpm | grep '\.spec$')
	rpm -ihv $srpm || exit $?
	mock -q -r $mock_chroot --buildsrpm --sources $source_dir --spec $spec || exit $?
	new_srpm_name=$(basename $(find $mock_result_dir -name ${srpm_name}\*${dist_tag}\*.src.rpm -type f))
# TODO optionalize
	mv $mock_result_dir/${new_srpm_name} $srpm_dir || exit $?
	new_srpm_name=$srpm_dir/$new_srpm_name
#rm $srpm
fi
mock -q -r $mock_chroot $new_srpm_name || exit $?
