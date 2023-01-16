#!/bin/sh

## set the root password
#'D;(%n`gN^yFjsc2cyLYo
#echo 'root:$1$W1i4J1fe$bybJlnRIdnIbkKZ0m6vxR.' | chpasswd -e

#echo 'EDITOR=/usr/bin/vim' > /etc/env.d/99livecd

cat << EOF > /root/.bashrc
. /etc/bash/bashrc

unset MAIL
shopt -s checkwinsize

alias minicom="/usr/bin/minicom --color=on --noinit --wrap"
EOF

cat << EOF > /usr/bin/vimpager
#!/bin/bash

cat $1 | col -b | vim -c 'se ft=man ro nomod nowrap ls=1 notitle ic' -c 'nmap <Space> <C-F>' -c 'nmap b <C-B>' -c 'nmap q :q!<CR>' -c 'norm L' -
EOF

chmod 755 /usr/bin/vimpager

cat << EOF >> /etc/fstab
none      /proc          proc    noauto,nodev,noexec,nosuid    0 0
none      /sys           sysfs   noauto,nodev,noexec,nosuid    0 0
tmpfs     /dev/shm       tmpfs   noauto,nodev,noexec,nosuid    0 0
none      /dev/pts       devpts  noauto,gid=5,mode=620         0 0

#none      /proc/bus/usb  usbfs   defaults               0 0
EOF

cp /usr/lib/gcc/*-pc-linux-gnu/*/*.so* /usr/lib/
ldconfig &>/dev/null

/bin/dd if=/dev/urandom of=/var/run/random-seed count=1 &> /dev/null

mkdir -p /boot
mkdir -p /mnt/server

#groupadd sshusers
#useradd -m -G users,sshusers,wheel -g users -s /bin/bash admin
#chown -R admin:users /home/admin

echo " * remove broken links"
for i in /bin/ /sbin/ /usr/bin/ /usr/sbin/ /lib64/; do
	find "${i}" -type l -xtype l | while read loc; do
		echo " ${loc}  symlink broken, removed"
		rm -f "${loc}"
	done
done

echo " * binary integrity check"
for i in /bin/* /sbin/* /usr/bin/* /usr/sbin/*; do
        ldd $i | grep -v 'use-ld=gold' | grep -qi "not found" && \
                echo $i && \
                ldd $i
done


exit 0

