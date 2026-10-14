#!/bin/sh

set -eu

TYPE='generic'
#TYPE='alternative'

unset LD_LIBRARY_PATH
unset LD_PRELOAD

ARCH=armv7hf-k5.4
LOADER=ld-linux-armhf.so.3
GLIBC=2.27
REPO="https://pdscomp.github.io/Kipware/main/armv7hf-k5.4"

echo 'Info: Checking for prerequisites and creating folders...'
if [ -d /opt ]; then
    echo 'Warning: Folder /opt exists!'
else
    mkdir /opt
fi
for folder in bin etc lib/opkg tmp var/lock
do
  if [ -d "/opt/$folder" ]; then
    echo "Warning: Folder /opt/$folder exists!"
    echo 'Warning: If something goes wrong please clean /opt folder and try again.'
  else
    mkdir -p /opt/$folder
  fi
done

echo 'Info: Opkg package manager deployment...'
ln -sf /lib/${LOADER} /opt/lib/${LOADER}
wget "${REPO}/installer/opkg" -O /opt/bin/opkg
chmod 755 /opt/bin/opkg
wget "${REPO}/installer/opkg.conf" -O /opt/etc/opkg.conf

echo 'Info: Basic packages installation...'
/opt/bin/opkg update
if [ $TYPE = 'alternative' ]; then
  /opt/bin/opkg install busybox
fi
/opt/bin/opkg install entware-release entware-upgrade

chmod 777 /opt/tmp

echo 'Info: Installing bootstrap files...'
mkdir -p /opt/etc/init.d /opt/etc/skel /opt/home /opt/root /opt/sbin /opt/share /opt/usr /opt/var/log /opt/var/run
wget "${REPO}/installer/rc.unslung" -O /opt/etc/init.d/rc.unslung
chmod 755 /opt/etc/init.d/rc.unslung
wget "${REPO}/installer/rc.func" -O /opt/etc/init.d/rc.func
chmod 644 /opt/etc/init.d/rc.func
wget "${REPO}/installer/profile" -O /opt/etc/profile
chmod 755 /opt/etc/profile
wget "${REPO}/installer/profile-kipware.sh" -O /opt/profile-kipware.sh
chmod 644 /opt/profile-kipware.sh
wget "${REPO}/installer/passwd.1" -O /opt/etc/passwd.1
wget "${REPO}/installer/group.1" -O /opt/etc/group.1
wget "${REPO}/installer/shells.1" -O /opt/etc/shells.1
wget "${REPO}/installer/dot-profile" -O /opt/etc/skel/.profile
cp /opt/etc/skel/.profile /opt/root/.profile
wget "${REPO}/installer/dot-inputrc" -O /opt/etc/skel/.inputrc
cp /opt/etc/skel/.inputrc /opt/root/.inputrc
: > /opt/etc/ld.so.conf

for fw_cmd in sbin/ifconfig sbin/route sbin/ip bin/netstat bin/sh bin/ash; do
  if [ -f "/${fw_cmd}" ] && [ ! -f "/opt/${fw_cmd}" ]; then
    ln -s "/${fw_cmd}" "/opt/${fw_cmd}"
  fi
done

for file in passwd group shells shadow gshadow; do
  if [ $TYPE = 'generic' ]; then
    if [ -f /etc/$file ]; then
      ln -sf /etc/$file /opt/etc/$file
    else
      [ -f /opt/etc/$file.1 ] && cp /opt/etc/$file.1 /opt/etc/$file
    fi
  else
    if [ -f /opt/etc/$file.1 ]; then
      cp /opt/etc/$file.1 /opt/etc/$file
    fi
  fi
done

[ -f /etc/localtime ] && ln -sf /etc/localtime /opt/etc/localtime

echo 'Info: Congratulations!'
echo 'Info: If there are no errors above then Entware was successfully initialized.'
echo 'Info: Add ". /opt/profile-kipware.sh" to /etc/profile or another shell startup file to add Kipware to PATH on login'
echo 'Info: Add "/opt/etc/init.d/rc.unslung start" to startup script for Entware services to start'
if [ $TYPE = 'alternative' ]; then
  echo 'Info: Use ssh server from Entware for better compatibility.'
fi
echo 'Info: Found a Bug? Please report at https://github.com/pdscomp/Kipware/issues'
