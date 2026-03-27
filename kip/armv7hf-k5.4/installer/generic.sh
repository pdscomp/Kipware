#!/bin/sh

set -eu

TYPE='generic'
#TYPE='alternative'

unset LD_LIBRARY_PATH
unset LD_PRELOAD

ARCH=armv7hf-k5.4
LOADER=ld-linux-armhf.so.3
GLIBC=2.27
REPO="https://pdscomp.github.io/Kipware/kip/armv7hf-k5.4"

echo 'Info: Checking for prerequisites and creating folders...'
if [ -d /kip ]; then
    echo 'Warning: Folder /kip exists!'
else
    mkdir /kip
fi
for folder in bin etc lib/opkg tmp var/lock
do
  if [ -d "/kip/$folder" ]; then
    echo "Warning: Folder /kip/$folder exists!"
    echo 'Warning: If something goes wrong please clean /kip folder and try again.'
  else
    mkdir -p /kip/$folder
  fi
done

echo 'Info: Opkg package manager deployment...'
wget "${REPO}/installer/opkg" -O /kip/bin/opkg
chmod 755 /kip/bin/opkg
wget "${REPO}/installer/opkg.conf" -O /kip/etc/opkg.conf

echo 'Info: Basic packages installation...'
/kip/bin/opkg update
if [ $TYPE = 'alternative' ]; then
  /kip/bin/opkg install busybox
fi
/kip/bin/opkg install entware-release entware-upgrade

chmod 777 /kip/tmp

echo 'Info: Installing bootstrap files...'
mkdir -p /kip/etc/init.d /kip/etc/skel /kip/home /kip/root /kip/sbin /kip/share /kip/usr /kip/var/log /kip/var/run
wget "${REPO}/installer/rc.unslung" -O /kip/etc/init.d/rc.unslung
chmod 755 /kip/etc/init.d/rc.unslung
wget "${REPO}/installer/rc.func" -O /kip/etc/init.d/rc.func
chmod 644 /kip/etc/init.d/rc.func
wget "${REPO}/installer/profile" -O /kip/etc/profile
chmod 755 /kip/etc/profile
wget "${REPO}/installer/passwd.1" -O /kip/etc/passwd.1
wget "${REPO}/installer/group.1" -O /kip/etc/group.1
wget "${REPO}/installer/shells.1" -O /kip/etc/shells.1
wget "${REPO}/installer/dot-profile" -O /kip/etc/skel/.profile
cp /kip/etc/skel/.profile /kip/root/.profile
wget "${REPO}/installer/dot-inputrc" -O /kip/etc/skel/.inputrc
cp /kip/etc/skel/.inputrc /kip/root/.inputrc
: > /kip/etc/ld.so.conf

for fw_cmd in sbin/ifconfig sbin/route sbin/ip bin/netstat bin/sh bin/ash; do
  if [ -f "/${fw_cmd}" ] && [ ! -f "/kip/${fw_cmd}" ]; then
    ln -s "/${fw_cmd}" "/kip/${fw_cmd}"
  fi
done

for file in passwd group shells shadow gshadow; do
  if [ $TYPE = 'generic' ]; then
    if [ -f /etc/$file ]; then
      ln -sf /etc/$file /kip/etc/$file
    else
      [ -f /kip/etc/$file.1 ] && cp /kip/etc/$file.1 /kip/etc/$file
    fi
  else
    if [ -f /kip/etc/$file.1 ]; then
      cp /kip/etc/$file.1 /kip/etc/$file
    fi
  fi
done

[ -f /etc/localtime ] && ln -sf /etc/localtime /kip/etc/localtime

echo 'Info: Congratulations!'
echo 'Info: If there are no errors above then Entware was successfully initialized.'
echo 'Info: Add /kip/bin & /kip/sbin to $PATH variable'
echo 'Info: Add "/kip/etc/init.d/rc.unslung start" to startup script for Entware services to start'
if [ $TYPE = 'alternative' ]; then
  echo 'Info: Use ssh server from Entware for better compatibility.'
fi
echo 'Info: Found a Bug? Please report at https://github.com/pdscomp/Kipware/issues'
