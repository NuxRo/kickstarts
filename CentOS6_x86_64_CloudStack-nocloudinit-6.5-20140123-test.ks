## CentOS CloudStack instance
skipx
text
install

url --url=http://mirrors.coreix.net/centos/6/os/x86_64/
repo --name=Updates --baseurl=http://mirrors.coreix.net/centos/6/updates/x86_64/
repo --name=epel --baseurl=http://mirrors.coreix.net/fedora-epel/6/x86_64/
#repo --name=rdo --baseurl=http://repos.fedorapeople.org/repos/openstack/cloud-init/epel-6/
repo --name=acsscripts --baseurl=http://li.nux.ro/download/cloudstack/rpms/el6/

lang en_GB.UTF-8
keyboard uk

timezone --utc Europe/London

network --onboot yes --device=eth0 --bootproto=dhcp


# we disable the firewall as the Security Groups will be used instead
firewall --disabled

# No reason Selinux can't stay on
selinux --enforcing 

authconfig --enableshadow --passalgo=sha512
# we randomise the password later
rootpw password

zerombr yes
clearpart --initlabel --all
# One partition to rule them all, no swap
part / --size=1024 --grow --fstype ext4 --asprimary

# we add serial tty for `virsh console`
bootloader --location=mbr --append="console=ttyS0,9600 console=tty0"


%packages --excludedocs
openssl
openssh-server
# cloud-init and growroot will expand the partition and filesystem to match the underlying image
#cloud-init
dracut-modules-growroot
ntp
wget
acpid
#do we want EPEL?
#epel-release
cloud-set-guest-password
cloud-set-guest-sshkey
%end

services --enabled=network,acpid,ntpd,sshd,cloud-set-guest-password,cloud-set-guest-sshkey --disabled=kdump

# halt the machine once everything is done
shutdown

%post --erroronfail
## sysprep stuff
# remove existing SSH keys - if generated - as they need to be unique
rm -rf /etc/ssh/*key*
# remove udev rules otherwise our NIC will be renamed to ethX+1
rm -f /etc/udev/rules.d/*-persistent-*
# the MAC address will change
sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-eth0 
# disable monitor feature in ntpd as it's used in nasty NTP amplification attacks
# https://isc.sans.edu/forums/diary/NTP+reflection+attack/17300
echo  disable monitor >> /etc/ntp.conf
# remove logs and temp files
yum -y clean all
rm -f /root/anaconda-ks.cfg
rm -f /root/install.log
rm -f /root/install.log.syslog
find /var/log -type f -delete
# randomise root password
openssl rand -base64 32 | passwd --stdin root
# remove the random seed, it needs to be unique and it will be autogenerated
rm -f /var/lib/random-seed 
# Kdump can use quite a bit of memory, do we want to keep it?
# sed -i s/crashkernel=auto/crashkernel=0@0/g /boot/grub/grub.conf

# tell the system to autorelabel? this takes some time and memory, maybe not advised
# touch /.autorelabel

# Disable the GSO and TSO options
# https://access.redhat.com/site/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Virtualization_Host_Configuration_and_Guest_Installation_Guide/ch10s04.html

cat << EOF > /sbin/ifup-local
#!/bin/bash
case "$1" in
eth0)
/sbin/ethtool -K $1 tso off gso off
;;
esac
exit 0
EOF

chmod +x /sbin/ifup-local
chcon --reference /sbin/ifup /sbin/ifup-local

# Enable the serial console login
echo ttyS0 >> /etc/securetty
sed -i 's@ACTIVE_CONSOLES=/dev/tty\[1-6\]@ACTIVE_CONSOLES="/dev/tty\[1-6\] /dev/ttyS0"@g' /etc/sysconfig/init

