
prefix='/local/sc'
source_dir="${prefix}/source"
build_dir="${prefix}/build"
tmp_dir="${prefix}/tmp"
portage_confdir="${prefix}/portage"
pkgcache_path="${prefix}/tmp/${version_stamp}/packages/"

unpack_portage() {
    mkdir -p "${tmp_dir}/${version_stamp}/portage"

    [ ! -e "${tmp_dir}/${version_stamp}/portage_unpacked" ] && {
        ebegin "     unpacking ${snapshot} to ${tmp_dir}/${version_stamp}/portage/"
        tar -xf "${source_dir}/${snapshot}" --directory="${tmp_dir}/${version_stamp}/portage/"
		rl=$?
        if [[ "${rl}" == "0" ]]; then
            eend '' 0
			echo all fine, touching "${tmp_dir}/${version_stamp}/portage_unpacked"
            date > "${tmp_dir}/${version_stamp}/portage_unpacked"
        else
            eend '' 1
        fi
    }

    return 0
}

stage1_unpack_upstream_seed() {
    mkdir -p "${tmp_dir}/${version_stamp}/stage1"

    [ ! -e "${tmp_dir}/${version_stamp}/stage1_upstream_unpacked" ] && {
        ebegin "     unpacking ${source_subpath} to ${tmp_dir}/${version_stamp}/stage1/"
        tar -xf "${source_dir}/${source_subpath}" --directory="${tmp_dir}/${version_stamp}/stage1/"
        rl=$?
        if [[ "${rl}" == "0" ]]; then
            eend '' 0
            date > "${tmp_dir}/${version_stamp}/stage1_upstream_unpacked"
        else
            eend '' 1
        fi
    }

    return 0
}

stage2_rsync() {
    mkdir -p "${tmp_dir}/${version_stamp}/stage2"

    [ ! -e "${tmp_dir}/${version_stamp}/stage2_synced" ] && {
        ebegin "     rsync ${tmp_dir}/${source_subpath} to ${tmp_dir}/${version_stamp}/stage2/"
        rsync -a --delete "${tmp_dir}/${source_subpath}/" "${tmp_dir}/${version_stamp}/stage2/"
        rl=$?
		rm -rf "${tmp_dir}/${version_stamp}/stage2/tmp/*.spec"
        if [[ "${rl}" == "0" ]]; then
            eend '' 0
            date > "${tmp_dir}/${version_stamp}/stage2_synced"
        else
            eend '' 1
        fi
    }

    return 0
}

stage2_rsync_root_overlay() {
    [ -n "${livecd_root_overlay}" -a -e "${livecd_root_overlay}" ] && {
        ebegin "     rsync ${livecd_root_overlay} to ${tmp_dir}/${version_stamp}/stage2/"
        rsync -a "${livecd_root_overlay}/" "${tmp_dir}/${version_stamp}/stage2/"
        rl=$?
		eend '' $rl
    }
    return 0
}

prepare_etc_portage() {
	stage=$1
	rl=0
    ebegin '     prepare configs and overlays'
    rsync -a --delete "${portage_confdir}/" "${tmp_dir}/${version_stamp}/stage${stage}/etc/portage/"
	rl=$((rl + $?))
    mkdir -p "${tmp_dir}/${version_stamp}/stage1/local/portage/overlay"
	rl=$((rl + $?))
    rsync -a --delete "${portage_overlay}/" "${tmp_dir}/${version_stamp}/stage${stage}/local/portage/overlay"
	rl=$((rl + $?))
    cp -f /etc/resolv.conf "${tmp_dir}/${version_stamp}/stage${stage}/etc/"
	rl=$((rl + $?))
	mkdir -p "${tmp_dir}/${version_stamp}/stage${stage}/dev/shm/"
	[ -e "${spec}_emerge" ] && {
		cp -f "${spec}_emerge" "${tmp_dir}/${version_stamp}/stage${stage}/dev/shm/emerge.spec"
		rl=$((rl + $?))
	}
	[ -e "${spec}_unmerge" ] && {
		cp -f "${spec}_unmerge" "${tmp_dir}/${version_stamp}/stage${stage}/dev/shm/unmerge.spec"
		rl=$((rl + $?))
	}
	[ -e "${spec}_empty" ] && {
		cp -f "${spec}_empty" "${tmp_dir}/${version_stamp}/stage${stage}/dev/shm/empty.spec"
		rl=$((rl + $?))
	}
	[ -e "${spec}_rm" ] && {
		cp -f "${spec}_rm" "${tmp_dir}/${version_stamp}/stage${stage}/dev/shm/rm.spec"
		rl=$((rl + $?))
	}
	[ -n "${livecd_fsscript}" -a -e "${build_dir}/${livecd_fsscript}" ] && {
		cp -f "${build_dir}/${livecd_fsscript}" "${tmp_dir}/${version_stamp}/stage${stage}/dev/shm/fsscript.sh"
	}
	eend '' ${rl}
    return ${rl}
}


mount_bind_start() {
    stage=$1

    [[ "${stage}" == "0" ]] && exit 1
    CHROOT_DIR=`readlink -f "${tmp_dir}/${version_stamp}/stage${stage}"`

    mount | grep -q "${CHROOT_DIR}/usr/portage" || {
        mkdir -p "${CHROOT_DIR}/usr/portage"
        mount -o bind /usr/portage "${CHROOT_DIR}/usr/portage"
    }
    mount | grep -q "${CHROOT_DIR}/local/portage/packages" || {
        mkdir -p "${CHROOT_DIR}/local/portage/packages"
        mount -o bind "${pkgcache_path}" "${CHROOT_DIR}/local/portage/packages"
    }
    mkdir -p ${CHROOT_DIR}/local/distfiles
    mount | grep -q "${CHROOT_DIR}/local/portage/distfiles" || {
        mkdir -p "${CHROOT_DIR}/local/portage/distfiles"
        mount -o bind /local/portage/distfiles "${CHROOT_DIR}/local/portage/distfiles"
    }
    mount | grep -q "${CHROOT_DIR}/dev " || \
        mount -o bind /dev "${CHROOT_DIR}/dev"
    mount | grep -q "${CHROOT_DIR}/dev/shm " || \
        mount -t tmpfs none "${CHROOT_DIR}/dev/shm"
    mount | grep -q "${CHROOT_DIR}/sys " || \
        mount -o bind /sys "${CHROOT_DIR}/sys"
    mount | grep -q "${CHROOT_DIR}/proc " || \
        mount -o bind /proc "${CHROOT_DIR}/proc"

    return 0
}

mount_bind_stop() {
    stage=$1

    [[ "${stage}" == "0" ]] && exit 1
    CHROOT_DIR=`readlink -f "${tmp_dir}/${version_stamp}/stage${stage}"`

    mount | grep -q "${CHROOT_DIR}/local/portage/distfiles " && \
        umount ${CHROOT_DIR}/local/portage/distfiles
    mount | grep -q "${CHROOT_DIR}/local/portage/packages " && \
        umount ${CHROOT_DIR}/local/portage/packages
    mount | grep -q "${CHROOT_DIR}/usr/portage " && \
        umount ${CHROOT_DIR}/usr/portage
    mount | grep -q "${CHROOT_DIR}/dev/shm " && \
        umount "${CHROOT_DIR}/dev/shm"
    mount | grep -q "${CHROOT_DIR}/dev " && \
        umount ${CHROOT_DIR}/dev
    mount | grep -q "${CHROOT_DIR}/sys " && \
        umount ${CHROOT_DIR}/sys
    mount | grep -q "${CHROOT_DIR}/proc " && \
        umount ${CHROOT_DIR}/proc

    return 0
}

mount_bind_stop_partial() {
    stage=$1

    [[ "${stage}" == "0" ]] && exit 1
    CHROOT_DIR=`readlink -f "${tmp_dir}/${version_stamp}/stage${stage}"`

    mount | grep -q "${CHROOT_DIR}/local/portage/distfiles " && \
        umount ${CHROOT_DIR}/local/portage/distfiles
    mount | grep -q "${CHROOT_DIR}/local/portage/packages " && \
        umount ${CHROOT_DIR}/local/portage/packages
    mount | grep -q "${CHROOT_DIR}/usr/portage " && \
        umount ${CHROOT_DIR}/usr/portage

    return 0
}

stage1_chroot() {

    ebegin "     chroot into ${tmp_dir}/${version_stamp}/stage1/"
    chroot "${tmp_dir}/${version_stamp}/stage1/" /bin/bash << EOF
        eselect news read &> /dev/null
        export FEATURES="-collision-protect"
        echo "   * update portage if needed"
        emerge -uq --usepkg portage portage-utils
        echo "   * update stage3 image"
        emerge -uq --usepkg \`qlist -IC\`
        echo "   * install custom list of packages"
        [ -e "/dev/shm/emerge.spec" ] && {
			emerge -uq --usepkg \`grep -Ev '(^#)|(^$)' /dev/shm/emerge.spec | xargs \`
			exit $?
		}
		exit 0
EOF
    return 0
}

stage2_0_chroot() {

    ebegin "chroot (1/2) into ${tmp_dir}/${version_stamp}/stage2/"
    chroot "${tmp_dir}/${version_stamp}/stage2/" /bin/bash << EOF
		[ ! -e /usr/bin/emerge ] && exit 0
        [ -e "/dev/shm/unmerge.spec" ] && {
        	echo "   * uninstall packages"
			emerge --unmerge \`grep -Ev '(^#)|(^$)' /dev/shm/unmerge.spec | xargs\`
		}
		exit 0
EOF
    return 0
}

stage2_1_chroot() {
    ebegin "chroot (2/2) into ${tmp_dir}/${version_stamp}/stage2/"
    chroot "${tmp_dir}/${version_stamp}/stage2/" /bin/bash << EOF
        eselect news read &> /dev/null
        [ -e "/dev/shm/rm.spec" ] && {
            for i in \`grep -Ev '(^#)|(^$)' /dev/shm/rm.spec | xargs\`; do
				rm -rf \${i}
			done
		}
        [ -e "/dev/shm/empty.spec" ] && {
            for i in \`grep -Ev '(^#)|(^$)' /dev/shm/empty.spec | xargs\`; do
				rm -rf \${i}/*
			done
		}
		[ -e /dev/shm/fsscript.sh ] && bash /dev/shm/fsscript.sh
		exit 0
EOF
    return 0
}

stage2_mksquashfs() {
    ebegin "     create squashfs image"
	mkdir -p "${tmp_dir}/${version_stamp}/cd"
	mksquashfs "${tmp_dir}/${version_stamp}/stage${stage}" "${tmp_dir}/${version_stamp}/cd/image.squashfs" -noappend > /dev/null
	rl=$?
	eend '' ${rl}
    return ${rl}
}

stage2_rsync_cd_overlay() {
	rl=0
    [ -n "${livecd_overlay}" -a -e "${livecd_overlay}" ] && {
        ebegin "     rsync ${livecd_overlay} to ${tmp_dir}/${version_stamp}/cd/"
        rsync -a "${livecd_overlay}/" "${tmp_dir}/${version_stamp}/cd/"
        rl=$?
		eend '' $rl
    }
    return $rl
}

stage2_mkisofs() {
	rl=0
    [ -n "${livecd_iso}" ] && {
        ebegin "     do mkisofs"
		cd "${tmp_dir}/${version_stamp}/cd/"
		mkisofs -quiet -J -R -l  -V "${livecd_volid}" -o "${livecd_iso}" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table "${tmp_dir}/${version_stamp}/cd/"
        rl=$?
		eend '' $rl
		ls -al "${livecd_iso}"
    }
    return $rl
}

