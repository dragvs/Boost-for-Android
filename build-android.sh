#!/bin/sh
# Copyright (C) 2010 Mystic Tree Games
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Moritz "Moss" Wundke (b.thax.dcg@gmail.com)
#
# <License>
#
# Build boost for android completly. It will download boost 1.45.0
# prepare the build system and finally build it for android

# Add common build methods
. `dirname $0`/build-common.sh

# -----------------------
# Command line arguments
# -----------------------

BOOST_VER1=1
BOOST_VER2=49
BOOST_VER3=0
register_option "--boost=<version>" boost_version "Boost version to be used, one of {1.49.0, 1.48.0, 1.45.0}, default is 1.49.0."
boost_version()
{
  if [ "$1" = "1.49.0" ]; then
    BOOST_VER1=1
    BOOST_VER2=49
    BOOST_VER3=0
  elif [ "$1" = "1.48.0" ]; then
    BOOST_VER1=1
    BOOST_VER2=48
    BOOST_VER3=0
  elif [ "$1" = "1.45.0" ]; then
    BOOST_VER1=1
    BOOST_VER2=45
    BOOST_VER3=0
  else
    echo "Unsupported boost version '$1'."
    exit 1
  fi
}

CLEAN=no
register_option "--clean"    do_clean     "Delete all previously downloaded and built files, then exit."
do_clean () {	CLEAN=yes; }

DOWNLOAD=no
register_option "--download" do_download  "Only download required files and clean up previus build. No build will be performed."

do_download ()
{
	DOWNLOAD=yes
	# Clean previus stuff too!
	CLEAN=yes
}

LIBRARIES=--with-libraries=date_time,filesystem,program_options,regex,signals,system,thread,iostreams

register_option "--with-libraries=<list>" do_with_libraries "Comma separated list of libraries to build."
do_with_libraries () { LIBRARIES="--with-libraries=$1"; }

register_option "--without-libraries=<list>" do_without_libraries "Comma separated list of libraries to exclude from the build."
do_without_libraries () {	LIBRARIES="--without-libraries=$1"; }



PROGRAM_PARAMETERS="<ndk-root>"
PROGRAM_DESCRIPTION=\
"       Boost For Android\n"\
"Copyright (C) 2010 Mystic Tree Games\n"\

extract_parameters $@

echo "Building boost version: $BOOST_VER1.$BOOST_VER2.$BOOST_VER3"

# -----------------------
# Build constants
# -----------------------

BOOST_DOWNLOAD_LINK="http://downloads.sourceforge.net/project/boost/boost/$BOOST_VER1.$BOOST_VER2.$BOOST_VER3/boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fboost%2Ffiles%2Fboost%2F${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3}%2F&ts=1291326673&use_mirror=garr"
BOOST_TAR="boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}.tar.bz2"
BOOST_DIR="boost_${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}"
BUILD_DIR="./build/"

# -----------------------

if [ $CLEAN = yes ] ; then
	echo "Cleaning: $BUILD_DIR"
	rm -f -r $PROGDIR/$BUILD_DIR
	
	echo "Cleaning: $BOOST_DIR"
	rm -f -r $PROGDIR/$BOOST_DIR
	
	echo "Cleaning: $BOOST_TAR"
	rm -f $PROGDIR/$BOOST_TAR

	echo "Cleaning: logs"
	rm -f -r logs
	rm -f build.log

  [ "$DOWNLOAD" = "yes" ] || exit 0
fi

# It is almost never desirable to have the
# boost-X_Y_Z directory from previous builds
# as this script doesn't check in which state
# it's been left (bootstrapped, patched, built, ...).
# Unless maybe during debug, in which case it's
# easy for a developer to commen out this code.

if [ -d "$PROGDIR/$BOOST_DIR" ]; then
	echo "Cleaning: $BOOST_DIR"
	rm -f -r $PROGDIR/$BOOST_DIR
fi

if [ -d "$PROGDIR/$BUILD_DIR" ]; then
	echo "Cleaning: $BUILD_DIR"
	rm -f -r $PROGDIR/$BUILD_DIR
fi


export AndroidNDKRoot=$PARAMETERS
if [ -z "$AndroidNDKRoot" ] ; then
	if [ -z "`which ndk-build`" ]; then
		dump "ERROR: You need to provide a <ndk-root>!"
		exit 1
	fi
	AndroidNDKRoot=`which ndk-build`
	AndroidNDKRoot=`dirname $AndroidNDKRoot`
	echo "Using AndroidNDKRoot = $AndroidNDKRoot"
fi

# Set default NDK release number
NDK_RN=4

NDK_RELEASE_FILE=$AndroidNDKRoot"/RELEASE.TXT"
# TODO: Remove this mess with selecting compiler version
# Most have now multiple compiler versions available
if [ -n "`cat $NDK_RELEASE_FILE | grep 'r5'`" ]; then
	NDK_RN=5

	if [ -n "`cat $NDK_RELEASE_FILE | grep 'crystax'`" ]; then
		CRYSTAX_WCHAR=1
	fi
elif [ -n "`cat $NDK_RELEASE_FILE | grep 'r7-crystax'`" ]; then
	NDK_RN=7
	CRYSTAX_WCHAR=1
elif [ -n "`cat $NDK_RELEASE_FILE | grep 'r8c'`" ]; then
	NDK_RN=8c
elif [ -n "`cat $NDK_RELEASE_FILE | grep 'r8b'`" ]; then
	NDK_RN=8b
elif [ -n "`cat $NDK_RELEASE_FILE | grep 'r8'`" ]; then
	NDK_RN=8
fi

# Check if android NDK path has been set 
if [ ! -n "${AndroidNDKRoot:+x}" ]
then
	echo "Environment variable: AndroidNDKRoot not set! Please enter tell me where you got the NDK root:"
	read AndroidNDKPatch
fi

# Check platform patch
case "$HOST_OS" in
    linux)
        Platfrom=linux-x86
        ;;
    darwin|freebsd)
        Platfrom=darwin-x86
        ;;
    windows|cygwin)
        Platfrom=windows-x86
        ;;
    *)  # let's play safe here
        Platfrom=linux-x86
esac

echo "NDK version: $NDK_RN"

case "$NDK_RN" in
	4)
		CXXPATH=$AndroidNDKRoot/build/prebuilt/$Platfrom/arm-eabi-4.4.0/bin/arm-eabi-g++
		CXXFLAGS=-I$AndroidNDKRoot/build/platforms/android-8/arch-arm/usr/include
		TOOLSET=gcc-androidR4
		;;
	5)
		CXXPATH=$AndroidNDKRoot/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$Platfrom/bin/arm-linux-androideabi-g++
		CXXFLAGS="-I$AndroidNDKRoot/platforms/android-8/arch-arm/usr/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/libs/armeabi/include \
				-I$AndroidNDKRoot/sources/wchar-support/include"
		TOOLSET=gcc-androidR5
		;;
	7)
		CXXPATH=$AndroidNDKRoot/toolchains/arm-linux-androideabi-4.6.3/prebuilt/$Platfrom/bin/arm-linux-androideabi-g++
		CXXFLAGS="-I$AndroidNDKRoot/platforms/android-9/arch-arm/usr/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/include/4.6.3 \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/libs/armeabi/4.6.3/include \
				-I$AndroidNDKRoot/sources/crystax/include"
		TOOLSET=gcc-androidR7
		;;
	8)
		CXXPATH=$AndroidNDKRoot/toolchains/arm-linux-androideabi-4.4.3/prebuilt/$Platfrom/bin/arm-linux-androideabi-g++
		CXXFLAGS="-I$AndroidNDKRoot/platforms/android-9/arch-arm/usr/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/libs/armeabi/include"
		TOOLSET=gcc-androidR8
		;;
	8b)
		CXXPATH=$AndroidNDKRoot/toolchains/arm-linux-androideabi-4.6/prebuilt/$Platfrom/bin/arm-linux-androideabi-g++
		CXXFLAGS="-I$AndroidNDKRoot/platforms/android-9/arch-arm/usr/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/4.6/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/4.6/libs/armeabi/include"
		TOOLSET=gcc-androidR8
		;;
	8c)
		CXXPATH=$AndroidNDKRoot/toolchains/arm-linux-androideabi-4.6/prebuilt/$Platfrom/bin/arm-linux-androideabi-g++
		CXXFLAGS="-I$AndroidNDKRoot/platforms/android-9/arch-arm/usr/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/4.6/include \
				-I$AndroidNDKRoot/sources/cxx-stl/gnu-libstdc++/4.6/libs/armeabi/include"
		TOOLSET=gcc-androidR8
		;;
	*)
		echo "Undefined or not supported Android NDK version!"
		exit 1
esac

echo Building with TOOLSET=$TOOLSET CXXPATH=$CXXPATH CXXFLAGS=$CXXFLAGS | tee $PROGDIR/build.log

# Check if the ndk is valid or not
if [ ! -f $CXXPATH ]
then
	echo "Cannot find C++ compiler at: $CXXPATH"
	exit 1
fi

# -----------------------
# Download required files
# -----------------------

# Downalod and unzip boost in a temporal folder and
if [ ! -f $BOOST_TAR ]
then
	echo "Downloading boost ${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3} please wait..."
	prepare_download
	download_file $BOOST_DOWNLOAD_LINK $PROGDIR/$BOOST_TAR
fi

if [ ! -f $PROGDIR/$BOOST_TAR ]
then
	echo "Failed to download boost! Please download boost ${BOOST_VER1}.${BOOST_VER2}.${BOOST_VER3} manually\nand save it in this directory as $BOOST_TAR"
	exit 1
fi

if [ ! -d $PROGDIR/$BOOST_DIR ]
then
	echo "Unpacking boost"
	tar xjf $PROGDIR/$BOOST_TAR
fi

if [ $DOWNLOAD = yes ] ; then
	echo "All required files has been downloaded and unpacked!"
	exit 0
fi

# ---------
# Bootstrap
# ---------
if [ ! -f ./$BOOST_DIR/bjam ]
then
	# Make the initial bootstrap
	echo "Performing boost bootstrap"

	cd $BOOST_DIR 
	./bootstrap.sh --prefix="./../$BUILD_DIR/" 			\
								 $LIBRARIES 											\
								 2>&1 | tee -a $PROGDIR/build.log

	if [ $? != 0 ] ; then
		dump "ERROR: Could not perform boostrap! See $TMPLOG for more info."
		exit 1
	fi
	cd $PROGDIR
	
	# -------------------------------------------------------------
	# Patching will be done only if we had a successfull bootstrap!
	# -------------------------------------------------------------

	# Apply patches to boost
	PATCH_BOOST_DIR=$PROGDIR/patches/boost-${BOOST_VER1}_${BOOST_VER2}_${BOOST_VER3}
	PATCH_NDK_DIR=$PATCH_BOOST_DIR/ndk-androidR${NDK_RN}

  for dir in $PATCH_BOOST_DIR $PATCH_NDK_DIR; do
	  if [ ! -d "$dir" ]; then
      echo "Could not find directory '$dir' while looking for patches"
      exit 1
    fi

	  PATCHES=`(cd $dir && ls *.patch | sort) 2> /dev/null`

    if [ -z "$PATCHES" ]; then
		  echo "No patches found in directory '$dir'"
      exit 1
    fi

    for PATCH in $PATCHES; do
      PATCH=`echo $PATCH | sed -e s%^\./%%g`
      SRC_DIR=$PROGDIR/$BOOST_DIR
		  PATCHDIR=`dirname $PATCH`
		  PATCHNAME=`basename $PATCH`
		  log "Applying $PATCHNAME into $SRC_DIR/$PATCHDIR"
		  cd $SRC_DIR && patch -p1 < $dir/$PATCH && cd $PROGDIR
		  if [ $? != 0 ] ; then
		  	dump "ERROR: Patch failure !! Please check your patches directory!"
        dump "       Try to perform a clean build using --clean ."
        dump "       Problem patch: $dir/$PATCHNAME"
		  	exit 1
		  fi
    done
  done
fi

echo "# ---------------"
echo "# Build using NDK"
echo "# ---------------"

# Build boost for android
echo "Building boost for android"
cd $BOOST_DIR
env PATH=`dirname $CXXPATH`:$PATH \
 AndroidNDKRoot=$AndroidNDKRoot NO_BZIP2=1 \
 ./bjam toolset=$TOOLSET -q \
 cxxflags="$CXXFLAGS" \
 link=static threading=multi --layout=versioned install 2>&1 | tee -a $PROGDIR/build.log
if [ $? != 0 ] ; then
	dump "ERROR: Failed to build boost for android!"
	exit 1
fi
cd $PROGDIR
dump "Done!"
