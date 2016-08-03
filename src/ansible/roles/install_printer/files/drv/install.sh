#!/bin/sh
SCRIPT_DIR=$(dirname "$0")

if sh "$SCRIPT_DIR/noarch/pre_install.sh" $@ ; then
	sh "$SCRIPT_DIR/noarch/worker.sh" $@ "printer-script"
	sh "$SCRIPT_DIR/noarch/worker.sh" $@ "scanner-script"
	sh "$SCRIPT_DIR/noarch/post_install.sh" $@
fi

