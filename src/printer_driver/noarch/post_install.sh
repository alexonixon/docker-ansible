#!/bin/sh
SCRIPT_DIR=$(dirname "$0")
. "$SCRIPT_DIR/packet.sh" 

while [ -n "$1" ]; do
	case $1 in
	-u) UNINSTALLMODE=1 ;;
	vendor=*) specify_vendor ${1#vendor=} ;;
	*) break ;;
	esac
	shift
done

common_init "common-post"

MSG_FINISH_INSTALL=$(gettext "Install finished")
MSG_FINISH_UNINSTALL=$(gettext "Uninstall finished")

if [ "$UNINSTALLMODE" ]; then
	print_message $MSG_FINISH_UNINSTALL
else
	print_message $MSG_FINISH_INSTALL
fi