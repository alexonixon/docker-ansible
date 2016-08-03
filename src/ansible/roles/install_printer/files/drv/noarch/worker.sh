resolve() {
	while [ -n "$1" ]; do
		"$SCRIPT_DIR/worker.sh" $PARAMS "$1"
		shift
	done
}


SCRIPT_DIR=$(dirname "$0")
. ${SCRIPT_DIR}/packet.sh

PARAMS=
MODULE_NAME=
while [ -n "$1" ]; do
	case $1 in
	-u) UNINSTALLMODE=1 ; PARAMS="$PARAMS -u";;
	vendor=*) specify_vendor ${1#vendor=}; PARAMS="$PARAMS vendor=$VENDOR" ;;
	-d) DEPENDENCIES=1 ; PARAMS="$PARAMS -d";;
	-v) CHECK_VERSION=1 ; PARAMS="$PARAMS -v";;
	-f) FORCE_INSTALL=1 ; PARAMS="$PARAMS -f";;
	-i) ;; # default
	--lazy) LAZY_INSTALL=1 ; PARAMS="$PARAMS --lazy";;
	--debug) DEBUG=1 ;PARAMS="$PARAMS --debug";;
	*) MODULE_NAME="$1" ;;
	esac
	shift
done


## obligatory functions in the package
# 	package_name()
# 	package_suffix()
#	do_install()
#	do_uninstall()

## optional function in the package
local_init() {
	return 0
} 
get_components() {
	return 0
}
dependencies() {
	return 0
}
human_readable_name() {
	echo ""
}

module_name=$(MODULE_NAME_TEMPLATE "$MODULE_NAME")
if ! [ -f "$module_name" ] ; then 
	log_message "can't find module $module_name"
	exit 1
fi

. "$module_name"

if [ "$DEPENDENCIES" ]; then 
	dependencies
	exit 0
fi

# $1 - component's list to verify
check_component $(get_components)

resolve $(dependencies)

common_init $(package_name) $(package_suffix)

if [ "$CHECK_VERSION" ] ; then
	print_version
	exit 0
fi

if ! have_root_permissions ; then
	abort_execution $(gettext "Root priviliges required")
fi

# initialization of special package variables
local_init

run "$(human_readable_name)"