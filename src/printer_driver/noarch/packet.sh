################################################################################
# Logging routines

log_init() {
# $1 - log file (optional, default log file based on script name and user name)
	LOG_FILE=/tmp/${SCRIPT_NAME}_$1_$(id -un)_log
	echo -n > "$LOG_FILE"
}

log_message() {
 #$1... - message (optional; if omitted then get message from stdio)
 #stdio - message data (ignored if message was passed with argument(s))
	if [ $# -gt 0 ]; then
		echo "$@" >> "$LOG_FILE" # echo "$@" >&2 # 
	else
		cat >> "$LOG_FILE" #  cat >&2 # 
	fi
}

print_message() {
	echo "**** $*"
	sync
}

print_message_sin_ln() {
	echo -n "**** $*"
	sync
}
print_error() {
	echo "ERROR: $*"
	sync
}
abort_execution() {
	echo "ERROR: "$@ $(gettext ", execution aborted")
	exit 4
}

################################################################################
# Environment routines

guess_architecture() {
	local ARCH
	log_message "guess_architecture"

	if { which rpm && rpm -q rpm; } >/dev/null 2>&1; then
		ARCH=`rpm -q rpm --qf "%{ARCH}\n"`
		log_message "rpm: <$ARCH>"
	elif which dpkg >/dev/null 2>&1; then
		ARCH=`dpkg --print-architecture`
		log_message "dpkg: <$ARCH>"
	else
		ARCH=`uname -m`
		log_message "uname: <$ARCH>"
	fi
	if [ "$ARCH" = "i386" -o "$ARCH" = "i486" -o "$ARCH" = "i586" -o "$ARCH" = "i686" ]; then
		ARCH=$ARCH_32
	elif [ "$ARCH" = "x86_64" -o "$ARCH" = "amd64" ]; then
		ARCH=$ARCH_64
	elif [ "$ARCH" = "arm" ]; then
		ARCH=$ARCH_ARM
	else
		return 1
	fi

	echo $ARCH
}
################################################################################
# Setup localization

setup_localization() {
	log_message "setup_localization"

	export TEXTDOMAIN=install
	export TEXTDOMAINDIR="$DIST_DIR/noarch/share/locale"
	export PATH="$PATH:$DIST_DIR/$HARDWARE_PLATFORM"

	which gettext >/dev/null 2>&1 || gettext() {
		echo "$1"
	}
}

have_root_permissions() {
	return $(id -u);	
}

################################################################################
# Copy files procedures

INSTALL_LOG_FILE_TMP=`mktemp -t installed_files.XXX`
install_log() {
 	while read src_dst
	do
		src=$( echo $src_dst | awk -F\" '{print $2}')
		dst=$(  echo $src_dst | awk -F\" '{print $4}')
		install "$src" "$dst" 
		chown root:root "$dst"
		echo $dst >> $INSTALL_LOG_FILE_TMP
	done
}
install_p() {
	if [ -n "$1" -a -n "$2" ]; then
		local dest="$2"
		if [ -d "$dest" ] ; then
			local filename=$(basename "$1")
			dest="$2/$filename"
		fi
		echo $dest >> $INSTALL_LOG_FILE_TMP
		install "$1" "$dest"
		return "$?"
	fi
	return 1
}

install_data_p() {
	if [ -n "$1" -a -n "$2" ]; then
		local dest="$2"
		if [ -d "$dest" ] ; then
			local filename=$(basename "$1")
			dest="$2/$filename"
		fi
		echo $dest >> $INSTALL_LOG_FILE_TMP
		install -m644 "$1" "$dest"
		return "$?"
	fi
	return 1
}

mkdir_log() {
	while read newdir
	do
		mkdir -p $newdir
		echo $newdir >> $INSTALL_LOG_FILE_TMP
	done
}
mkdir_p() {
	if [ -n "$1" ]; then
		echo $1 >> $INSTALL_LOG_FILE_TMP
		mkdir -p $1
		return "$?"
	fi
	return 1
}

lns_p() {
	if [ -n "$1" -a -n "$2" ]; then
		local dest="$2"
		if [ -d "$dest" ] ; then
			local filename=$(basename "$1")
			dest="$2/$filename"
		fi
		echo $dest >> $INSTALL_LOG_FILE_TMP
		ln -sf "$1" "$dest"	
		return "$?"	
	fi
	return 1
}

install_lns_p() {
	if [ -z "$1" -o -z "$2" -o -z "$3" ] ; then
		return 1
	fi
		
	
	local dest="$2"
	if [ -d "$dest" ] ; then
		local filename1=$(basename "$1")
		dest="$2/$filename1"
	fi
	echo $dest >> $INSTALL_LOG_FILE_TMP
	if ! install "$1" "$dest" ; then 
		return 1
	fi
	
	
	local dest2="$3"
	if [ -d "$dest2" ] ; then
		local filename2=$(basename "$1")
		dest2="$dest2/$filename2"
	fi
	echo $dest2 >> $INSTALL_LOG_FILE_TMP
	ln -sf "$dest" "$dest2"
	return "$?"
}

install_lns_data_p() {
	if [ -z "$1" -o -z "$2" -o -z "$3" ] ; then
		return 1
	fi
		
	
	local dest="$2"
	if [ -d "$dest" ] ; then
		local filename1=$(basename "$1")
		dest="$2/$filename1"
	fi
	echo $dest >> $INSTALL_LOG_FILE_TMP
	if ! install -m644 "$1" "$dest" ; then 
		return 1
	fi
	
	
	local dest2="$3"
	if [ -d "$dest2" ] ; then
		local filename2=$(basename "$1")
		dest2="$dest2/$filename2"
	fi
	echo $dest2 >> $INSTALL_LOG_FILE_TMP
	ln -sf "$dest" "$dest2"
	return "$?"
}

touch_p() {
	if [ -z "$1" ] ; then
		return 1
	fi
	echo "$1" >> $INSTALL_LOG_FILE_TMP
	touch "$1"
}

copy_directories() {
	if ! test -d $2 ; then
		print_message "ERROR: " $(gettext "Destination directory") $2 $(gettext "does not exist. Copy operation aborted.")
		return
	fi

	#destination directory must be ended by "/",
	#but ended with only one "/",
	#because "install" doesn't work correctly with SELinux context 
	#if we have double slash at the begining of the folder path	
	echo "$2" | grep '/$' > /dev/null 2>&1
	if [ "$?" = "1" ] ; then 
		dst_dir=`echo "$2"/`
	else
		dst_dir=$2
	fi

	for src_dir in $1 ; do
		if test -d $src_dir ; then
			( cd $src_dir && find . -type d ) | grep -v ^\.$ | \
				sed -e "s:\(^\./\)\(.*\):$dst_dir\2:"  | mkdir_log
			( cd $src_dir && find . -type f -o -type l ) | \
sed -e "s:\(^\./\)\(.*\):\"$src_dir/\2\" \"$dst_dir\2\":"  | install_log
		fi
	done
}

################################################################################
# resolving dependences and versions

create_dependences() {
#$1 - subordinate
# Make reference to common (vendor independent) printer driver part
	log_message "INSTALL_DIR<$INSTALL_DIR>"
	log_message "VENDOR_SPECIFIC<$VENDOR_SPECIFIC>"
	log_message "DIST_DIR<$DIST_DIR>"
	log_message "PACKAGE_NAME<$PACKAGE_NAME>"
	log_message "create_dependences DIR<$INSTDIR_REFERENCES> lns</opt/$VENDOR_LC> label<$INSTDIR_REFERENCES/$VENDOR_LC>" 
	mkdir -p "$INSTDIR_REFERENCES" && ln -sfv "/opt/$VENDOR_LC" "$INSTDIR_REFERENCES" 2>&1 | log_message
	
	return 0	
}

remove_dependences() {
#$1 - subordinate
# return 0 if we could completely remove the component

	rm -f "$INSTDIR_REFERENCES/$VENDOR_LC"
	rmdir -p "$INSTDIR_REFERENCES" 2>/dev/null		

	if test -d "$INSTDIR_REFERENCES" ; then
		return 1;
	fi

	return 0;
}
get_version_part() {
# $1 - version file
# $2 - version part ( > 0 )

	cat "$1" | awk -F\. "{print \$$2}"
}

print_version() {
	echo "${PACKAGE_NAME}${PACKAGE_SUFFIX}\t `cat "$DIST_VERSION_FILE"`"
}
check_version() {
# @return :
# 0 -	if versions are differernt and the new one is biger then the old one
#		or FORCE_INSTALL=1 
# 1 - 	if verisions are identical or the new one is less then the old one 
	if [ "$FORCE_INSTALL" ]; then
		return 0 
	fi
	if ! [ -f "$VERSION_FILE" ] ; then 
		return 0
	fi
	local first=""
	local second=""
	local i="1"
	while true ; do
		first=$(get_version_part "$VERSION_FILE" "$i" )
		second=$(get_version_part "$DIST_VERSION_FILE" "$i" )
		if [ -z "$first" ] ; then
			if [ -z "$second" ] ; then 
				return 1 	#the same version was installed
			else
				return 0	# have to install
			fi
		fi
		if [ $(( first < second )) = "1" ] ; then 
			return 0; # have to install 
		elif [ $(( first > second )) = "1" ] ; then
			return 1; # the newer version was installed
		fi
		i=$(( i + 1 ))
	done
	
	cat "$DIST_VERSION_FILE" 2>&1 | log_message
	return 0
}

remove_all_files() {
	if ! [ -f "$INSTALL_LOG_FILE" ] ; then 
		return 1
	fi

	local LINES=$( wc -l "$INSTALL_LOG_FILE" | awk '{print $1}')
	for i in $(seq 1 $LINES ) ; do
		local NAME=$(tail -$i "$INSTALL_DIR/.files" | head -1)
		if [ -f "$NAME" ] ; then 
			rm -f "$NAME"
		elif [ -h "$NAME" ] ; then
			rm -f "$NAME"
		elif [ -d "$NAME" ] ; then
			rmdir "$NAME"
		fi
	done
	rm -f "$INSTALL_LOG_FILE"
	return 0
}

################################################################################
# Special output

output_blank_line() {
	echo ""
}
show_cut_line() {
	echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
}

read_KEY_PRESSED() {
	if [ "$LAZY_INSTALL" ] ; then
		KEY_PRESSED=""
		echo ""
		return
	fi
	if ! read KEY_PRESSED ; then 
		echo "read KEY_PRESSED error" | log_message
		exit 1
	fi
}

ask_any_key_or_q() {
	print_message_sin_ln $(gettext "Press Enter to continue or q and then Enter to quit: ")
	read_KEY_PRESSED
	if test "$KEY_PRESSED" = "q" || test "$KEY_PRESSED" = "Q" ; then
		print_message "$TERMINATED_BY_USER"
		exit 1
	fi
}
################################################################################
# 

get_oem_field() {
# $1 - field name
	local fname="$1"
	[ -z "$fname" ] && return 1
	
	grep "^$fname=" "$OEM_FILE" 2>/dev/null | sed 's/\"//g' | sed "s/$fname=\(.*\)/\1/"
}

specify_vendor() {
	if [ -n "$1" ]; then
		VENDOR=$1
	elif [ -f "$OEM_FILE" ] ; then
		VENDOR=`grep '^VENDOR=' $OEM_FILE 2>/dev/null | sed 's/VENDOR=\(.*\)/\1/'`
	fi


	VENDOR_UC=`echo $VENDOR | tr a-z A-Z`
	VENDOR_LC=`echo $VENDOR | tr A-Z a-z`
	
	test -n "$VENDOR" || abort_execution "VENDOR undefined"
}
################################################################################
# 
check_component() {
	if [ "$UNINSTALLMODE" ] ; then
		return
	fi

	local MISSED="$1"
	if [ -n "$MISSED" ] ; then 
		abort_execution $(gettext "component is missed" ) " <$MISSED>"
	fi
}

################################################################################
# Main engine

run(){
# $1 - human_readable_name
	# uninstall mode 	
	if [ "$UNINSTALLMODE" ] ; then 
		if [ "$VENDOR_SPECIFIC" ] || remove_dependences ; then 
			log_message "I remove files from <$INSTALL_DIR>"
			remove_all_files
			do_uninstall
			( cd "$INSTALL_DIR_OPT" && 	rmdir -p "$INSTALL_DIR_PREFIX" ) 2>/dev/null 
		fi	
		return 	
	fi

	# install mode
	mkdir -p "$INSTALL_DIR" 2>&1 | log_message
	test "$VENDOR_SPECIFIC" || create_dependences 
	if check_version ; then
		log_message "REMOVE ALL PREVIOS FILES<$PACKAGE_NAME>"
		remove_all_files
		log_message "DO INSTALL PACKET<$PACKAGE_NAME>"
		do_install
		install_p "$DIST_VERSION_FILE" "$VERSION_FILE" 2>&1 | log_message
		#install_files_for_future_uninstallation
		mv "$INSTALL_LOG_FILE_TMP" "$INSTALL_LOG_FILE"
		if [ "$DEBUG" ] ; then 
			print_message "Install the product("$1")[$(cat "$DIST_VERSION_FILE")]"
		fi
	else
		rm "$INSTALL_LOG_FILE_TMP"
		if [ "$DEBUG" ] ; then 
			print_message "Skip the product("$1")[$(cat "$DIST_VERSION_FILE")] installation. Version [$(cat "$VERSION_FILE")] has been already installed"
		fi
		log_message "SKIP INSTALL PACKET<$PACKAGE_NAME>"	
	fi
}

common_init() {
# $1 package name. determines the name of setup directory
# $2 --vendor-specific property. determines if setup directory 
# is common ( /opt/smfp-common ) or vendor specific ( /opt/$VENDOR )
# also package name and --vendor-specific property determine log file name
# it will be /tmp/install_packetname-[common]_user_log

	if ! [ "$1" ]; then 
		abort_execution " PACKAGE NAME is undefined"
	fi

	PACKAGE_NAME="$1"
	PACKAGE_SUFFIX="$2"

	if [ "$PACKAGE_SUFFIX" ] ; then
			VENDOR_SPECIFIC=1
	fi
	
	log_init "${PACKAGE_NAME}${PACKAGE_SUFFIX}"
	
	log_message "SCRIPT_NAME<$SCRIPT_NAME>"
	log_message "SCRIPT_ABS_PATH<$SCRIPT_ABS_PATH>"
	log_message "DIST_DIR<$DIST_DIR>"

	HARDWARE_PLATFORM=$( guess_architecture )
	
	if [ $? -ne 0 ]; then
		log_message "Failed to guess architecture"
		exit 1
	fi
	
	log_message "HARDWARE_PLATFORM=<$HARDWARE_PLATFORM>"

	if [ "$HARDWARE_PLATFORM" = "$ARCH_64" ]; then
		PLSFX=64
		LIBSFX=64
		if ! [ -d /usr/lib${LIBSF} ] ; then
			LIBSFX=
		fi
	fi

	setup_localization

	## abort_execution uses gettext, so we might call it only after setup_localization
	if [ "$HARDWARE_PLATFORM" != "$ARCH_32" -a "$HARDWARE_PLATFORM" != "$ARCH_64" ]; then
		abort_execution "Unsuppored hardware platform \"$HARDWARE_PLATFORM\""
	fi

	
	if [ -z $VENDOR ]; then 
		specify_vendor
	fi

	INSTALL_DIR_PREFIX=$(INSTALL_DIR_PREFIX_TEMPLATE)
	INSTALL_DIR="$INSTALL_DIR_OPT/$INSTALL_DIR_PREFIX"
	INSTDIR_REFERENCES="$INSTALL_DIR/.usedby"
	INSTALL_LOG_FILE="$INSTALL_DIR/.files"
	VERSION_FILE="$INSTALL_DIR/.version"
	
	DIST_VERSION_FILE=$(DIST_VERSION_FILE_TEMPLATE)
	
	TERMINATED_BY_USER=$(gettext "Terminated by user")
}

SCRIPT_NAME=$(basename "$0" .sh)
SCRIPT_ABS_PATH=$( cd $SCRIPT_DIR && pwd )

DIST_DIR=
OEM_FILE=

HARDWARE_PLATFORM=
ARCH_32=i386
ARCH_64=x86_64
ARCH_ARM=arm

PLSFX=
LIBSFX=

LINUX_DIST=

INSTALL_DIR_OPT=/opt
INSTALL_DIR_COMMON_BASE=
INSTALL_DIR_COMMON_LIB=

INSTALL_DIR=
INSTALL_DIR_PREFIX=
INSTDIR_REFERENCES=

INSTALL_LOG_FILE=
VERSION_FILE=
DIST_VERSION_FILE=

PACKAGE_NAME=
PACKAGE_SUFFIX=

UNINSTALLMODE=
VENDOR_SPECIFIC=

FORCE_INSTALL=
CHECK_VERSION=
DEPENDENCIES=

TERMINATED_BY_USER=

unset DBUS_SESSION_BUS_ADDRESS

export PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"

. ${SCRIPT_DIR}/config

