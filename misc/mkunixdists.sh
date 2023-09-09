#!/bin/sh

################################################################
# mkunixdists.sh -- shell script to generate Unix distributions
#
# Usage: mkunixdists.sh <archive>[.zip] [tmpdir]
#
# This generates all the Unix-specific distributions.  The
# existing ZIP format is fine on Unix too, but we'll generate
# here a .tar.gz in Unix format (no `fix.sh unix' necessary) and
# also an end-user distribution which just creates and installs
# the library, without examples, documentation, etc.  I suppose
# there's a danger that people will download this as a cut-down
# development version, but if we shoot those people then this
# problem will be solved.  This script might need a lot of disk
# space, but no more than the existing zipup.sh needs. :)



################################################################
# First process the arguments

if [ $# -lt 1 -o $# -gt 2 ]; then
	echo "Usage: mkunixdists.sh <archive>[.zip] [tmpdir]"
	exit 1
fi

# Sort out `dir', adding a trailing `/' if necessary
if [ $# -gt 1 ]; then
	dir=$(echo "$2" | sed -e 's/\([^/]\)$/\0\//').tmp
else
	dir=.tmp
fi



################################################################
# Error reporter

error() {
	echo "Error occured, aborting" ; rm -rf $dir ; exit 1
}


################################################################
# Unzip the archive and run fix.sh unix

mkdir $dir || error

echo "Unzipping $1 to $dir"
	unzip -qq $1 -d $dir || error
echo "Running 'fix.sh unix'"
	(cd $dir/allegro && rm -f makefile && . fix.sh unix --dtou >/dev/null) || error

# When making x.y.z.w releases the version number is not available in
# makefile.ver so read it from the environment.
if test -z "$VERSION"
then
	echo "Checking version number"
	basename=$(sed -n -e 's/shared_version = /allegro-/p' $dir/allegro/makefile.ver)
	basename2=$(sed -n -e 's/shared_version = /allegro-enduser-/p' $dir/allegro/makefile.ver)
else
	echo "Using version $VERSION"
	basename="allegro-$VERSION"
	basename2="allegro-enduser-$VERSION"
fi

echo "Renaming 'allegro' to '$basename'"
	mv $dir/allegro $dir/$basename || error

################################################################
# Make .tar.gz distributions

mktargz() {
	echo "Creating $1.tar"
	(cd $dir && tar -cf - $basename) > $1.tar || error
	echo "gzipping to $1.tar.gz"
	gzip $1.tar || error
}

# Create the developers' archive
mktargz $basename

# Hack'n'slash
echo "Stripping to form end-user distribution"
(cd $dir/$basename && {
	(cd src && rm -rf beos qnx dos mac ppc win)
	(cd obj && rm -rf bcc32 beos qnx djgpp mingw32 msvc watcom)
	(cd lib && rm -rf bcc32 beos qnx djgpp mingw32 msvc watcom)
	(cd include && rm -f bealleg.h qnxalleg.h macalleg.h winalleg.h)
	(cd misc && rm -f cmplog.pl dllsyms.lst findtext.sh fixpatch.sh fixver.sh)
	(cd misc && rm -f allegro-config-qnx.sh zipup.sh zipwin.sh *.bat *.c)
	mkdir .saveme
	cp readme.txt docs/build/unix.txt docs/build/linux.txt .saveme
	rm -rf demo docs examples resource setup tests tools
	rm -f AUTHORS CHANGES THANKS *.txt fix* indent* readme.* allegro.mft
	rm -f makefile.all makefile.be makefile.qnx makefile.bcc makefile.dj
	rm -f makefile.mgw makefile.mpw makefile.vc makefile.wat makefile.tst
	rm -f xmake.sh
	rm -f keyboard.dat language.dat
	mv .saveme/* .
	rmdir .saveme
	{       # Tweak makefile.in
		cp makefile.in makefile.old &&
		cat makefile.old |
		sed -e "s/INSTALL_TARGETS = .*/INSTALL_TARGETS = mini-install/" |
		sed -e "s/DEFAULT_TARGETS = .*/DEFAULT_TARGETS = lib modules/" |
		cat > makefile.in &&
		rm -f makefile.old
	}
})

# Create the end users' archive
mktargz $basename2


################################################################
# Create SRPM distribution
#
# We don't actually create the binary RPMs here, since that
# will really need to be done on many different machines.
# Instead we'll build the source RPM.
#
# This requires you to have Red Hat's default RPM build system
# properly set up, so we'll skip it if that's not the case.

rpmdir=
[ -d /usr/src/redhat ] && rpmdir=/usr/src/redhat
[ -d /usr/src/packages ] && rpmdir=/usr/src/packages
[ -d /usr/src/RPM ] && rpmdir=/usr/src/RPM
[ -d /usr/src/rpm ] && rpmdir=/usr/src/rpm

if [ -n "$rpmdir" ]; then
	echo "Creating SRPM"
	echo "Enter your root password if prompted"
	su -c "(\
		cp -f $basename.tar.gz $rpmdir/SOURCES ;\
		cp -f $dir/$basename/misc/icon.xpm $rpmdir/SOURCES ;\
		rpm -bs $dir/$basename/misc/allegro.spec ;\
		mv -f $rpmdir/SRPMS/allegro-*.rpm . ;\
		rm -f $rpmdir/SOURCES/icon.xpm ;\
		rm -f $rpmdir/SOURCES/$basename.tar.gz ;\
	)"
fi


################################################################
# All done!

rm -rf $dir
echo "All done!"

