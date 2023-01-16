#!/bin/bash

cd initramfs
find ./ | cpio --quiet -o -H newc --owner root:root --force-local > ../cd_overlay/isolinux/initramfs.cpio
xz -e --check=none --compress --force -9 < ../cd_overlay/isolinux/initramfs.cpio > ../cd_overlay/isolinux/initramfs.igz &&
	rm ../cd_overlay/isolinux/initramfs.cpio

