#!/bin/sh
#
# Install a p56 PBX

PROD=voclarion

SCREEN=`which screen`
if [ -z "$SCREEN" ]
then
  yum -y install screen
fi

if [ -z "$STY" ]
then
  echo "NOTE: You are not running this session under screen - this is strongly recommended"
  echo "See: http://www.rackaid.com/blog/linux-screen-tutorial-and-how-to/"
  echo "You have 5 seconds to press Ctrl-C to abort"
  sleep 5
  echo "Ok - continuing.."
fi

VER="2.5"

REL="D"
RELEASE_ARCH=`arch`
if [ "$RELEASE_ARCH" = "i686" ]
then
  RELEASE_ARCH="i386"
fi

LSB=`which lsb_release`
if [ -z "$LSB" ]
then
  yum -y install redhat-lsb
fi

RHMAJOR=`lsb_release -r | awk ' { print $2; }' | cut -f1 -d.`

# from this point on all output will be send to a log file 
# (See last line of this script)
{

echo `date` Installing $PROD $VER$REL on CentOS$RHMAJOR $RELEASE_ARCH..
echo
sleep 3

REPP56="ftp://yum.p5060.net/pub/dist/P56/$VER/CentOS$RHMAJOR/p56/$REL/$RELEASE_ARCH/os"

echo ""
echo "Installing $PROD $VER $REL $RELEASE_ARCH on CentOS$RHMAJOR, please wait...."
echo ""

if selinuxenabled
then
  echo "Please set SELINUX=disabled in /etc/sysconfig/selinux."
  echo "Then REBOOT and try installing again."
  exit 1
fi

ifconfig eth0 > /dev/null 2>&1
if [ "$?" = "1" ]
then
  echo "Sorry, your system does not have an eth0 interface. This is required."
  echo "This software wil NOT work without an eth0 interface. STOP."
  exit 1
fi

# If we run run on a 64 bit system, remove all i386 and i686 packages.
if [ $RELEASE_ARCH = "x86_64" ]
then
   yum remove \*.i\?86 -y
fi

# for 64-bit systems, install zlib, libstdc++ 32 bit versions, because aapt needs those
if [ $RELEASE_ARCH = "x86_64" ]
then
	yum -y install libzip.i686 libstdc++.i686	
fi

# install yum-priorities and some other useful packages
yum -y install yum-priorities telnet iotop strace openssh-clients rsync screen tcpdump vim-enhanced mlocate \
 bind bind-utils gdb tftp ftp lynx system-config-network-tui jwhois nc mc minicom nano unixODBC patch ngrep \
 watch acpid
if [ $? -gt 0 ]
then
  echo "ERRORS occured: INSTALLATION INCOMPLETE"
  exit 1
fi

# make sure acpid is running, or reboot from the cloud portal is not working
/etc/init.d/acpid start
chkconfig --level 235 acpid on

# Now, install the repository files
rm -f p56-release*rpm
wget $REPP56/p56/RPMS/p56-release-$VER-*.noarch.rpm
if [ $? -gt 0 ]
then
  echo "ERRORS occured: INSTALLATION INCOMPLETE"
  exit 1
fi

rm -f p56-repo*rpm
wget $REPP56/p56/RPMS/p56-repo-$VER-*.noarch.rpm
if [ $? -gt 0 ]
then
  echo "ERRORS occured: INSTALLATION INCOMPLETE"
  exit 1
fi

if [ $RHMAJOR -eq 5 ]
then
  wget http://fedora-epel.mirror.lstn.net/5/i386/epel-release-5-4.noarch.rpm
  rpm -Uvh epel-release-5-4.noarch.rpm
fi

rpm -Uvh p56-release-$VER-*.noarch.rpm
rpm -Uvh p56-repo-$VER-*.noarch.rpm
sed -i -e s/gpgcheck=1/gpgcheck=0/g /etc/yum.repos.d/p56.repo

# clean yum cache
yum clean metadata

# Update CentOS.
yum -y update
if [ $? -gt 0 ]
then
  echo "ERRORS occured: INSTALLATION INCOMPLETE"
  exit 1
fi

# if postgresql /var/lib/pgsql/ does not exists, init postgreSQL.
if [ ! -d /var/lib/pgsql/data ]
then
  if [ ! -d /var/lib/pgsql ]
  then
    yum -y install postgresql-server
  fi
  test=`/sbin/service postgresql 2>&1|grep initdb`
  if [ -n "$test" ]
  then
    /sbin/service postgresql initdb
  fi
fi

# Remove installed ntp
rpm --quiet -q ntp
if [ $? = 0 ]
then
  rpm -e ntp --nodeps
fi

# install httpd first, because of a bug in nagios-common: it does not require 
# httpd to be installed, but does depend on the apache user.
yum -y install httpd
if [ $? -gt 0 ]
then
  echo "ERRORS occured: INSTALLATION INCOMPLETE"
  exit 1
fi


# Now we're ready to install
yum -y install $PROD
if [ $? -gt 0 ]
then
  echo "ERRORS occured: INSTALLATION INCOMPLETE"
  exit 1
fi

# if nothing was found at all, yum might still exit with exit code 0. 
# so check if voclarion actually was installed using rpm. Error out if not.
rpm -q voclarion
if [ $? -gt 0 ]
then
  echo "ERRORS occured: INSTALLATION INCOMPLETE"
  exit 1
fi

# Make sure the debuginfo packages are installed
debuginfo-install -y asterisk astiumd

echo "NOTE: The currently supported countries are:"
echo ""
echo "      Belgium"
echo "      Canada"
echo "      Germany"
echo "      Latvia"
echo "      Netherlands"
echo "      Netherlands Antilles"
echo "      Romania"
echo "      United Kingdom"
echo "      United States"
echo "      South Africa"
echo ""
echo "If you want your country to be supported, just send an email to: support@p5060.net"
echo ""
echo "Are you running behind a firewall, ensure the proper ports are opened."
echo ""
echo "**************************************************************************"
echo "* "`date`" Done. NOW REBOOT YOUR MACHINE."
echo "* Then point your browser to this machine and login using system/admin."
echo "**************************************************************************"
echo ""

} 2>&1 | tee -a /var/log/p56.log

#EOF
