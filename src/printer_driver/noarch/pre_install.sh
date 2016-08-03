#!/bin/sh 
compare_insensitive() {
	echo "$1" | grep -qi "^${2}$"
}

detect_legacy_uld() {
	if ! [ -d /opt ] ; then
		return 1
	fi
	
	for i in $( ls /opt ) ; do
		if compare_insensitive $i $VENDOR ; then
			if [ -f /opt/$i/mfp/uninstall/guiuninstall ]; then
				LEGACY_ULD_NAME="$i"
				return 0
			fi
		fi
	done
	return 1
}

# lecence file finding
find_eula_file() {
	EULA_DIR="$DIST_DIR/noarch/license"

	EULA_LOCALE="${LC_ALL:-${LC_MESSAGES:-${LANG}}}"
	EULA_LOCALE=`echo "${EULA_LOCALE}" | tr A-Z a-z`

	log_message "EULA_LOCALE: '$EULA_LOCALE'"

	while [ -n "${EULA_LOCALE}" ] ; do
		EULA_FILE="${EULA_DIR}/eula-${EULA_LOCALE}.txt"
		#log_variable EULA_FILE
		if [ -r "${EULA_FILE}" ] ; then break ; fi
		EULA_LOCALE=`echo "${EULA_LOCALE}" | sed 's/.$//'` # drop last symbol
	done
	log_message "EULA_LOCALE: '$EULA_LOCALE'"
	if [ -z "${EULA_LOCALE}" ] ; then
		EULA_FILE="${EULA_DIR}/eula.txt"
		if [ ! -r "${EULA_FILE}" ] ; then
			EULA_FILE=""
		fi
	fi

	log_message "EULA_FILE: '$EULA_FILE'"
	echo "${EULA_FILE}"
}

#show_license() {
#	EULA_FILE=`find_eula_file`
#	EULA_PAGER="${PAGER:-`which more`}"
#	
#	log_message "EULA_PAGER: '$EULA_PAGER'"
#
#	if [ -n "${EULA_FILE}" -a -n "${EULA_PAGER}" ] ; then
#		ICONV_BINARY=`which iconv`
#		# show EULA:
#		show_cut_line
#		if [ -n "$ICONV_BINARY" ] ; then
#			cat "${EULA_FILE}" | "${ICONV_BINARY}" -c -f "UTF-8" | ${EULA_PAGER}
#		else
#			"${EULA_PAGER}" "${EULA_FILE}"
#		fi
#		
#		show_cut_line
#
#		# ask for agreement:
#		output_blank_line
#		print_message_sin_ln $(gettext "Do you agree ? [y/n]")": "
#		read_KEY_PRESSED
#		if [ "$KEY_PRESSED" != "y" ] ; then
#			print_message "$TERMINATED_BY_USER"
#			exit 1
#		fi
#	fi
#}

SCRIPT_DIR=$(dirname "$0")
. "$SCRIPT_DIR/packet.sh" 

while [ -n "$1" ]; do
	case $1 in
	-u) UNINSTALLMODE=1 ;;
	vendor=*) specify_vendor ${1#vendor=} ;;
	--lazy) LAZY_INSTALL=1 ;;
	esac
	shift
done

common_init "common-pre"

if ! have_root_permissions ; then
	abort_execution $(gettext "Root priviliges required")
fi

MSG_RUN_MODE_UNINSTALL=$(gettext "Running uninstall")
MSG_RUN_MODE_INSTALL=$(gettext "Running install")
MSG_OLD_ULD_DETECTED1=$(gettext "Old version of Unified Linux Driver is detected.") 
MSG_OLD_ULD_DETECTED2=$(gettext "In order to continue the installation please remove old version.")
MSG_OLD_ULD_DETECTED3=$(gettext "If you want to delete old version press 'y'.To finish the intallation press 'Enter': ")

LEGACY_ULD_NAME=

if [ "$UNINSTALLMODE" ]; then
	print_message $MSG_RUN_MODE_UNINSTALL
else
	print_message $MSG_RUN_MODE_INSTALL
fi
#ask_any_key_or_q

if detect_legacy_uld ; then
	print_message $MSG_OLD_ULD_DETECTED1
	print_message $MSG_OLD_ULD_DETECTED2
	print_message_sin_ln $MSG_OLD_ULD_DETECTED3
	
#	read_KEY_PRESSED
#	if test "$KEY_PRESSED" = "y" || test "$KEY_PRESSED" = "Y" ; then
		/opt/$LEGACY_ULD_NAME/mfp/uninstall/uninstall.sh -t 
#	else
#		print_message "$TERMINATED_BY_USER"
#		exit 1
#	fi
fi

if ! [ "$UNINSTALLMODE" ]; then 
	if  [ "$LAZY_INSTALL" ]; then
#		show_license
            exit 1
	fi
fi
