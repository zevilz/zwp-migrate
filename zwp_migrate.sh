#!/usr/bin/env bash
# Migrate WordPress installations via SSH.
# URL: https://github.com/zevilz/zwp-migrate
# Author: Alexandr "zEvilz" Emshanov
# License: MIT
# Version: 1.3.0

# shellcheck disable=SC2046
# shellcheck disable=SC2089
# shellcheck disable=SC2086
# shellcheck disable=SC2090
# shellcheck disable=SC2016
# shellcheck disable=SC2181

#pushToLog()
#{
#	if [[ $# -eq 2 ]]; then
#		echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $1: $2" >> $SCRIPT_LOGS_DIR/main.log
#		if [ -f "$SCRIPT_ERRORS_TMP" ]; then
#			cat "$SCRIPT_ERRORS_TMP" >> $SCRIPT_LOGS_DIR/main.log
#			rm "$SCRIPT_ERRORS_TMP"
#		fi
#	else
#		$SETCOLOR_FAILURE
#		echo "Internal error handling error! Exiting..."
#		$SETCOLOR_NORMAL
#		exit 1
#	fi
#}

checkHostFormat()
{
	if [[ "$1" =~ ^localhost(:[0-9]+)?$ ]] || [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(:[0-9]+)?$ ]] || [[ $(echo "$1" | grep -P "(?=^.{4,253}$)(^(?:[a-z0-9](?:(?:[a-z0-9\-]){0,61}[a-z0-9])?\.)+[a-z0-9\-]{2,}(:[0-9]+)?$)") == "$1" ]]; then
		echo 1
	else
		echo 0
	fi
}

checkUserFormat()
{
	if [[ "$1" =~ ^[A-Za-z0-9_\.][A-Za-z0-9_\.\-]*$ ]]; then
		echo 1
	else
		echo 0
	fi
}

checkFullPathFormat()
{
	if [[ "$1" =~ ^/ ]]; then
		echo 1
	else
		echo 0
	fi
}

checkUrlFormat() {
	if [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(:[0-9]+)?$ ]]; then
		echo 1
	elif echo "$1" | grep -P -q '^https?://([a-z0-9\-\.]+|localhost)(:[0-9]+)?(/.*)?$'; then
		echo 1
	else
		echo 0
	fi
}

checkDBNameFormat()
{
	echo 1
}

checkDBUserFormat()
{
	echo 1
}

cleanup()
{
	if [ -n "$1" ]; then
		echo "$1"
	fi

	if [ -z "$1" ]; then
		echo -n "  removing the script temporary files..."
	fi

	# source tmp errors file

	if [ -z "$SOURCE_HOST" ]; then
		rm -f "$SOURCE_SCRIPT_ERRORS_TMP" > /dev/null 2>/dev/null
	elif [ "$FAIL_REMOTE" -eq 0 ]; then
		$SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "rm -f \"$SOURCE_SCRIPT_ERRORS_TMP\" > /dev/null 2>/dev/null" > /dev/null 2>/dev/null
	else
		echo -n
	fi

	SOURCE_RESULT="$?"

	# target tmp errors file

	if [ -z "$TARGET_HOST" ]; then
		rm -f "$TARGET_SCRIPT_ERRORS_TMP" > /dev/null 2>/dev/null
	elif [ "$FAIL_REMOTE" -eq 0 ]; then
		$SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "rm -f \"$TARGET_SCRIPT_ERRORS_TMP\" > /dev/null 2>/dev/null" > /dev/null 2>/dev/null
	else
		echo -n
	fi

	TARGET_RESULT="$?"

	# rsync exclude list file

	rm -f "$RSYNC_EXCLUDE_LIST_FILE" > /dev/null 2>/dev/null

	RSYNC_EXCLUDE_RESULT="$?"

	# result

	if [ -z "$1" ]; then
		if [ "$SOURCE_RESULT" -eq 0 ] && [ "$TARGET_RESULT" -eq 0 ] && [ "$RSYNC_EXCLUDE_RESULT" -eq 0 ]; then
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
		else
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			$SETCOLOR_NORMAL
		fi
	fi

	# ssh session file

	if [[ -n "$SOURCE_HOST" && "$SOURCE_AUTH_TYPE" == "pass" ]] || [[ -n "$TARGET_HOST" && "$TARGET_AUTH_TYPE" == "pass" ]]; then
		if [ -z "$1" ]; then
			echo -n "  removing files for ssh session..."
		fi

		rm -f "$SCRIPT_SSH_PASS_TMP" > /dev/null 2>/dev/null

		RESULT="$?"

		if [ -z "$1" ]; then
			if [ "$RESULT" -eq 0 ]; then
				$SETCOLOR_SUCCESS
				echo "[OK]"
				$SETCOLOR_NORMAL
			else
				$SETCOLOR_FAILURE
				echo "[FAIL]"
				$SETCOLOR_NORMAL
			fi
		fi
	fi

	echo
}

usage()
{
	echo
	echo "Usage: bash $0 [options]"
	echo
	echo "Simple tool for right migrate WordPress sites between servers and shared hostings "
	echo "with SSH access via rsync and WP-CLI"
	echo
	echo "Parameters:"
	echo
	echo "    -h, --help                     Shows this help."
	echo
	echo "    -v, --version                  Shows script version."
	echo
	echo "    -q, --quiet                    Automatically confirm migration after checks."

	echo "    --non-interactive              Enable non-interactive mode."
	echo
	echo "    --source-host=<host>:<port>    Source host IP/hostname with ssh port (if it not 22) "
	echo "                                   separated by colon (don't set it if you run script "
	echo "                                   on this host)."
	echo
	echo "    --source-user=<username>       System user on source host (source site owner)."
	echo
	echo "    --source-user-pass='<pass>'    System user password on source host (password "
	echo "                                   of source site owner; don't set it if you run "
	echo "                                   script as this user)."
	echo
	echo "    --source-path=<path>           Full path to source site root."
	echo
	echo "    --target-host=<host>:<port>    Target host IP/hostname with ssh port (if it not 22) "
	echo "                                   separated by colon (don't set it if you run script "
	echo "                                   on this host)."
	echo
	echo "    --target-user=<username>       System user on target host (target site owner)."
	echo
	echo "    --target-user-pass='<pass>'    System user password on target host (password "
	echo "                                   of target site owner; don't set it if you run "
	echo "                                   script as this user)."
	echo
	echo "    --target-path=<path>           Full path to target site root."
	echo
	echo "    --target-site-url=<url>        Full url of target site with protocol (http/https)."
	echo
	echo "    --target-db-host=<host>:<port> Target site database host with port (if it not "
	echo "                                   default 3306) separated by colon (don't set it if "
	echo "                                   db server is localhost with default 3306 port)."
	echo
	echo "    --target-db-name=<database>    Target site database name."
	echo
	echo "    --target-db-user=<user>        Target site database user with full access rights "
	echo "                                   to target site database."
	echo
	echo "    --target-db-pass=<pass>        Target site database user password."
	echo
	echo "    --target-wpcli-path=<path>     Custom WP-CLI path."
	echo
	echo "    --target-php-path=<path>       Path to custom PHP binary for running WP-CLI."
	echo
	echo "    --files-exclude=<patterns>     File patterns to exclude from files sync separated "
	echo "                                   by spaces (pattern `wp-content/cache` already included "
	echo "                                   to this list)."
	echo
}

# Vars

# script vars
SCRIPT_INSTANCE_KEY=$(tr -cd 'a-zA-Z0-9' < /dev/urandom | head -c 10)
SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETCOLOR_GREY="echo -en \\033[0;2m"
BOLD_TEXT=$(tput bold)
NORMAL_TEXT=$(tput sgr0)
INTERACTIVE=1
NO_ASK=0
HELP=0
SHOW_VERSION=0
#SCRIPT_LOGS_DIR="/var/log/zwp_migrate"

# errors
ERRORS_CHECK=0
ERRORS_MIGRATE=0
FAIL_BOTH_REMOTE=0
FAIL_USER=0
FAIL_WP=0
FAIL_SOURCE_DB=0
FAIL_REMOTE=0
FAIL_TMP_PATH=0

# source host
SOURCE_HOST=
SOURCE_PORT=22
SOURCE_AUTH_TYPE="key"
SOURCE_USER=
SOURCE_USER_PASS=
SOURCE_PATH=
SOURCE_SITE_URL=
SOURCE_DB_HOST=
SOURCE_DB_PORT=3306
SOURCE_DB_NAME=
SOURCE_DB_USER=
SOURCE_DB_PASS=
SOURCE_TMP_PATH=
SOURCE_SCRIPT_ERRORS_TMP=

# target host
TARGET_HOST=
TARGET_PORT=22
TARGET_AUTH_TYPE="key"
TARGET_USER=
TARGET_USER_PASS=
TARGET_PATH=
TARGET_SITE_URL=
TARGET_DB_HOST=
TARGET_DB_PORT=3306
TARGET_DB_NAME=
TARGET_DB_USER=
TARGET_DB_PASS=
TARGET_TMP_PATH=
TARGET_SCRIPT_ERRORS_TMP=
TARGET_WPCLI_PATH=
TARGET_PHP_PATH=

# migration vars
RSYNC_SOURCE_HOST=
RSYNC_TARGET_HOST=
RSYNC_PORT=
RSYNC_CHOWN=
RSYNC_EXCLUDE_LIST='wp-content/cache'
RSYNC_EXCLUDE_LIST_FILE="${TMPDIR-/tmp}/zwp_migrate.tmp.rsync_exclude.${SCRIPT_INSTANCE_KEY}"
CMD_SOURCE_DB_PASS=
CMD_TARGET_DB_PASS=
#SYNC=0
#SYNC_EXCLUDE=

# ssh pass access
SETSID=
SCRIPT_SSH_PASS_TMP="${TMPDIR-/tmp}/zwp_migrate.tmp.sshpass.${SCRIPT_INSTANCE_KEY}"

# wp-cli
WPCLI=
WPCLI_DOWNLOADED=0

# php
PHP=

# Parse options

while true ; do
	if [[ "$1" = "--non-interactive" ]] ; then
		INTERACTIVE=0

	elif [[ "$1" = "--quiet" || "$1" = "-q" ]] ; then
		NO_ASK=1

	elif [[ "$1" = "--help" || "$1" = "-h" ]] ; then
		HELP=1

	elif [[ "$1" = "--version" || "$1" = "-v" ]] ; then
		SHOW_VERSION=1

	elif [ "${1#--source-host=}" != "$1" ] ; then
		SOURCE_HOST="${1#--source-host=}"

	elif [ "${1#--source-user=}" != "$1" ] ; then
		SOURCE_USER="${1#--source-user=}"

	elif [ "${1#--source-user-pass=}" != "$1" ] ; then
		SOURCE_USER_PASS="${1#--source-user-pass=}"
		SOURCE_AUTH_TYPE="pass"

	elif [ "${1#--source-path=}" != "$1" ] ; then
		SOURCE_PATH="${1#--source-path=}"

	elif [ "${1#--target-host=}" != "$1" ] ; then
		TARGET_HOST="${1#--target-host=}"

	elif [ "${1#--target-user=}" != "$1" ] ; then
		TARGET_USER="${1#--target-user=}"

	elif [ "${1#--target-user-pass=}" != "$1" ] ; then
		TARGET_USER_PASS="${1#--target-user-pass=}"
		TARGET_AUTH_TYPE="pass"

	elif [ "${1#--target-path=}" != "$1" ] ; then
		TARGET_PATH="${1#--target-path=}"

	elif [ "${1#--target-site-url=}" != "$1" ] ; then
		TARGET_SITE_URL="${1#--target-site-url=}"
		TARGET_SITE_URL=$(echo "$TARGET_SITE_URL" | sed 's/\/$//')

	elif [ "${1#--target-db-host=}" != "$1" ] ; then
		TARGET_DB_HOST="${1#--target-db-host=}"

	elif [ "${1#--target-db-name=}" != "$1" ] ; then
		TARGET_DB_NAME="${1#--target-db-name=}"

	elif [ "${1#--target-db-user=}" != "$1" ] ; then
		TARGET_DB_USER="${1#--target-db-user=}"

	elif [ "${1#--target-db-pass=}" != "$1" ] ; then
		TARGET_DB_PASS="${1#--target-db-pass=}"

	elif [ "${1#--files-exclude=}" != "$1" ] ; then
		RSYNC_EXCLUDE_LIST="${RSYNC_EXCLUDE_LIST} ${1#--files-exclude=}"

	elif [ "${1#--target-wpcli-path=}" != "$1" ] ; then
		TARGET_WPCLI_PATH="${1#--target-wpcli-path=}"

	elif [ "${1#--target-php-path=}" != "$1" ] ; then
		TARGET_PHP_PATH="${1#--target-php-path=}"

	elif [ -z "$1" ] ; then
		break
	else
		echo
		$SETCOLOR_FAILURE
		echo "Unknown key detected!" 1>&2
		$SETCOLOR_NORMAL
		usage
		exit 1
	fi
	shift
done

# Show help

if [ "$HELP" -eq 1 ]; then
	usage
	exit 0
fi

# Show version

if [ $SHOW_VERSION -eq 1 ]; then
	CUR_VERSION=$(grep 'Version:\ ' $0 | cut -d ' ' -f3)
	echo $CUR_VERSION
	exit 0
fi

if [ $INTERACTIVE -eq 1 ]; then

	# source host

	echo "${BOLD_TEXT}# Source host${NORMAL_TEXT}"

	while true; do
		echo
		echo "IP or hostname of source server (localhost by default)."
		echo "Set port after colon if you use custom ssh port (ex.: \"123.123.123.123:2222\")"
		echo
		echo -n "Type source server IP or hostname (empty value for localhost) > "

		read -r SOURCE_HOST

		if [ -n "$SOURCE_HOST" ]; then
			if [ $(checkHostFormat "$SOURCE_HOST") -eq 1 ]; then
				break
			else
				$SETCOLOR_FAILURE
				echo "Wrong server IP or hostname format!"
				$SETCOLOR_NORMAL
			fi
		else
			break
		fi

	done

	echo

	# source user

	echo "${BOLD_TEXT}# Source username${NORMAL_TEXT}"

	while true; do
		echo
		echo "System username on source server."
		echo
		echo -n "Type username of source server > "

		read -r SOURCE_USER

		if [ -z "$SOURCE_USER" ]; then
			$SETCOLOR_FAILURE
			echo "Username is empty!"
			$SETCOLOR_NORMAL
		else
			if [ $(checkUserFormat "$SOURCE_USER") -eq 0 ]; then
				$SETCOLOR_FAILURE
				echo "Wrong username format!"
				$SETCOLOR_NORMAL
			else
				break
			fi
		fi

	done

	echo

	if [ -n "$SOURCE_HOST" ]; then

		# remote source auth type

		echo "${BOLD_TEXT}# Remote source auth type${NORMAL_TEXT}"

		while true; do
			echo
			echo "Select \"SSH key\" if auth to remote host via SSH key."
			echo "Select \"password\" if auth to remote host only by password "
			echo "or you don't know about SSH keys."
			echo
			echo "1. SSH key"
			echo "2. password"
			echo
			echo -n "Choose SSH auth type [1] > "

			read -r SOURCE_AUTH_TYPE_KEY

			case "$SOURCE_AUTH_TYPE_KEY" in
				1) echo -n
					SOURCE_AUTH_TYPE="key"
					break
					;;
				2) echo -n
					SOURCE_AUTH_TYPE="pass"
					break
					;;
				"") echo -n
					SOURCE_AUTH_TYPE="key"
					break
					;;
				*) echo
					$SETCOLOR_FAILURE
					echo "Type correct value!"
					$SETCOLOR_NORMAL
					;;
			esac

		done

		echo

		if [[ "$SOURCE_AUTH_TYPE" == "pass" ]]; then

			# source user password

			echo "${BOLD_TEXT}# Source user password${NORMAL_TEXT}"

			while true; do
				echo
				echo -n "Type password for remote user (password not visible) > "

				read -r -s SOURCE_USER_PASS

				if [ -z "$SOURCE_USER_PASS" ]; then
					echo
					$SETCOLOR_FAILURE
					echo "User pass is empty!"
					$SETCOLOR_NORMAL
				else
					break
				fi
			done

			echo
			echo

		fi

	fi

	# source path

	echo "${BOLD_TEXT}# Source path${NORMAL_TEXT}"

	while true; do
		echo
		echo "WordPress installation full path."
		echo
		echo -n "Type WordPress installation path on source server > "

		read -r SOURCE_PATH

		if [ -z "$SOURCE_PATH" ]; then
			$SETCOLOR_FAILURE
			echo "Path is empty!"
			$SETCOLOR_NORMAL
		else
			if [ $(checkFullPathFormat "$SOURCE_PATH") -eq 0 ]; then
				$SETCOLOR_FAILURE
				echo "Wrong path format!"
				$SETCOLOR_NORMAL
			else
				break
			fi
		fi

	done

	echo

	if [[ -z "$SOURCE_HOST" ]]; then

		# target host

		echo "${BOLD_TEXT}# Target host${NORMAL_TEXT}"

		while true; do
			echo
			echo "IP or hostname of target server (localhost by default)."
			echo "Set port after colon if you use custom ssh port (ex.: \"123.123.123.123:2222\")"
			echo
			echo -n "Type target server IP or hostname (empty value for localhost) > "

			read -r TARGET_HOST

			if [ -n "$TARGET_HOST" ]; then
				if [ $(checkHostFormat "$TARGET_HOST") -eq 1 ]; then
					break
				else
					$SETCOLOR_FAILURE
					echo "Wrong server IP or hostname format!"
					$SETCOLOR_NORMAL
				fi
			else
				break
			fi

		done

		echo

	fi

	# target user

	echo "${BOLD_TEXT}# Target username${NORMAL_TEXT}"

	while true; do
		echo
		echo "System username on target server."
		echo
		echo -n "Type username of target server > "

		read -r TARGET_USER

		if [ -z "$TARGET_USER" ]; then
			$SETCOLOR_FAILURE
			echo "Username is empty!"
			$SETCOLOR_NORMAL
		else
			if [ $(checkUserFormat "$TARGET_USER") -eq 0 ]; then
				$SETCOLOR_FAILURE
				echo "Wrong username format!"
				$SETCOLOR_NORMAL
			else
				break
			fi
		fi

	done

	echo

	if [ -n "$TARGET_HOST" ]; then

		# remote target auth type

		echo "${BOLD_TEXT}# Remote target auth type${NORMAL_TEXT}"

		while true; do
			echo
			echo "Select \"SSH key\" if auth to remote host via SSH key."
			echo "Select \"password\" if auth to remote host only by password "
			echo "or you don't know about SSH keys."
			echo
			echo "1. SSH key"
			echo "2. password"
			echo
			echo -n "Choose SSH auth type [1] > "

			read -r TARGET_AUTH_TYPE_KEY

			case "$TARGET_AUTH_TYPE_KEY" in
				1) echo -n
					TARGET_AUTH_TYPE="key"
					break
					;;
				2) echo -n
					TARGET_AUTH_TYPE="pass"
					break
					;;
				"") echo -n
					TARGET_AUTH_TYPE="key"
					break
					;;
				*) echo
					$SETCOLOR_FAILURE
					echo "Type correct value!"
					$SETCOLOR_NORMAL
					;;
			esac

		done

		echo

		if [[ "$TARGET_AUTH_TYPE" == "pass" ]]; then

			# target user password

			echo "${BOLD_TEXT}# Target user password${NORMAL_TEXT}"

			while true; do
				echo
				echo -n "Type password for remote user (password not visible) > "

				read -r -s TARGET_USER_PASS

				if [ -z "$TARGET_USER_PASS" ]; then
					echo
					$SETCOLOR_FAILURE
					echo "User pass is empty!"
					$SETCOLOR_NORMAL
				else
					break
				fi
			done

			echo
			echo

		fi

	fi

	# target path

	echo "${BOLD_TEXT}# Target path${NORMAL_TEXT}"

	while true; do
		echo
		echo "WordPress installation full path."
		echo
		echo -n "Type WordPress installation path on target server > "

		read -r TARGET_PATH

		if [ -z "$TARGET_PATH" ]; then
			$SETCOLOR_FAILURE
			echo "Path is empty!"
			$SETCOLOR_NORMAL
		else
			if [ $(checkFullPathFormat "$TARGET_PATH") -eq 0 ]; then
				$SETCOLOR_FAILURE
				echo "Wrong path format!"
				$SETCOLOR_NORMAL
			else
				break
			fi
		fi

	done

	echo

	# target wp url

	echo "${BOLD_TEXT}# Target WordPress URL${NORMAL_TEXT}"

	while true; do
		echo
		echo "WordPress full URL (with protocol)."
		echo
		echo -n "Type WordPress URL from target server > "

		read -r TARGET_SITE_URL

		if [ -z "$TARGET_SITE_URL" ]; then
			$SETCOLOR_FAILURE
			echo "URL is empty!"
			$SETCOLOR_NORMAL
		else
			TARGET_SITE_URL=$(echo "$TARGET_SITE_URL" | sed 's/\/$//')
			if [ $(checkUrlFormat "$TARGET_SITE_URL") -eq 0 ]; then
				$SETCOLOR_FAILURE
				echo "Wrong url format!"
				$SETCOLOR_NORMAL
			else
				break
			fi
		fi

	done

	echo

	# target db host

	echo "${BOLD_TEXT}# Target DB host${NORMAL_TEXT}"

	while true; do
		echo
		echo "WordPress database host on target server (localhost with default 3306 port by default)."
		echo "Set port after colon if you use custom port (ex.: \"123.123.123.123:2222\")"
		echo
		echo -n "Type DB host (empty value for localhost) > "

		read -r TARGET_DB_HOST

		if [ -n "$TARGET_DB_HOST" ]; then
			if [ $(checkHostFormat "$TARGET_DB_HOST") -eq 1 ]; then
				break
			else
				$SETCOLOR_FAILURE
				echo "Wrong DB host format!"
				$SETCOLOR_NORMAL
			fi
		else
			TARGET_DB_HOST="localhost"
			break
		fi

	done

	echo

	# target db name

	echo "${BOLD_TEXT}# Target DB name${NORMAL_TEXT}"

	while true; do
		echo
		echo "WordPress database name on target server."
		echo
		echo -n "Type DB name > "

		read -r TARGET_DB_NAME

		if [ -z "$TARGET_DB_NAME" ]; then
			$SETCOLOR_FAILURE
			echo "DB name is empty!"
			$SETCOLOR_NORMAL
		else
			if [ $(checkDBNameFormat "$TARGET_DB_NAME") -eq 0 ]; then
				$SETCOLOR_FAILURE
				echo "Wrong DB name format!"
				$SETCOLOR_NORMAL
			else
				break
			fi
		fi

	done

	echo

	# target db user

	echo "${BOLD_TEXT}# Target DB user${NORMAL_TEXT}"

	while true; do
		echo
		echo "WordPress database user on target server."
		echo
		echo -n "Type DB user > "

		read -r TARGET_DB_USER

		if [ -z "$TARGET_DB_USER" ]; then
			$SETCOLOR_FAILURE
			echo "DB user is empty!"
			$SETCOLOR_NORMAL
		else
			if [ $(checkDBUserFormat "$TARGET_DB_USER") -eq 0 ]; then
				$SETCOLOR_FAILURE
				echo "Wrong DB user format!"
				$SETCOLOR_NORMAL
			else
				break
			fi
		fi

	done

	echo

	# target db user pass

	echo "${BOLD_TEXT}# Target DB user pass${NORMAL_TEXT}"

	while true; do
		echo
		echo "WordPress database user pass on target server."
		echo
		echo -n "Type DB user pass (password not visible) > "

		read -r -s TARGET_DB_PASS

		if [ -z "$TARGET_DB_PASS" ]; then
			echo
			$SETCOLOR_FAILURE
			echo "Target DB pass is empty!"
			$SETCOLOR_NORMAL
		else
			break
		fi
	done

	echo
	echo

else

	echo
	echo -n "Checking input data..."

	if [ -n "$SOURCE_HOST" ] && [ $(checkHostFormat "$SOURCE_HOST") -eq 0 ]; then
		$SETCOLOR_FAILURE
		echo "Wrong source server IP or hostname format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -z "$SOURCE_USER" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Source username not set!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ $(checkUserFormat "$SOURCE_USER") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong source username format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -n "$SOURCE_HOST" ] && [[ "$SOURCE_AUTH_TYPE" == "pass" ]] && [ -z "$SOURCE_USER_PASS" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Source user password is empty!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -z "$SOURCE_PATH" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Source path not set!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ $(checkFullPathFormat "$SOURCE_PATH") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong source path format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -n "$TARGET_HOST" ] && [ $(checkHostFormat "$TARGET_HOST") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong target server IP or hostname format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -z "$TARGET_USER" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Target username not set!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ $(checkUserFormat "$TARGET_USER") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong target username format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -n "$TARGET_HOST" ] && [[ "$TARGET_AUTH_TYPE" == "pass" ]] && [ -z "$TARGET_USER_PASS" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Target user password is empty!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -z "$TARGET_PATH" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Target path not set!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ $(checkFullPathFormat "$TARGET_PATH") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong target path format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	TARGET_SITE_URL=$(echo "$TARGET_SITE_URL" | sed 's/\/$//')

	if [ -z "$TARGET_SITE_URL" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Target WP URL not set!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ $(checkUrlFormat "$TARGET_SITE_URL") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong target WP URL format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -z "$TARGET_DB_HOST" ]; then
		TARGET_DB_HOST="localhost"
	elif [ -n "$TARGET_DB_HOST" ] && [ $(checkHostFormat "$TARGET_DB_HOST") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong target DB host format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -z "$TARGET_DB_NAME" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Target DB name not set!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ $(checkDBNameFormat "$TARGET_DB_NAME") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong target DB name format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -z "$TARGET_DB_USER" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Target DB user not set!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ $(checkDBUserFormat "$TARGET_DB_USER") -eq 0 ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Wrong target DB user format!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ -z "$TARGET_DB_PASS" ]; then
		if [ "$ERRORS_CHECK" -eq 0 ]; then
			echo
		fi
		$SETCOLOR_FAILURE
		echo "  Target DB password not set!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	fi

	if [ "$ERRORS_CHECK" -eq 0 ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	fi

fi

# Prepare vars

if [[ "$SOURCE_HOST" == *:* ]]; then
	SOURCE_PORT=$(echo "$SOURCE_HOST" | awk -F ':' '{print $2}')
	SOURCE_HOST=$(echo "$SOURCE_HOST" | awk -F ':' '{print $1}')
fi

SOURCE_PATH=$(echo "$SOURCE_PATH" | sed 's/\/$//')

if [[ "$TARGET_HOST" == *:* ]]; then
	TARGET_PORT=$(echo "$TARGET_HOST" | awk -F ':' '{print $2}')
	TARGET_HOST=$(echo "$TARGET_HOST" | awk -F ':' '{print $1}')
fi

TARGET_PATH=$(echo "$TARGET_PATH" | sed 's/\/$//')

if [ -n "$TARGET_DB_PASS" ]; then
	CMD_TARGET_DB_PASS="-p${TARGET_DB_PASS}"
fi

if [ -n "$SOURCE_HOST" ]; then
	RSYNC_SOURCE_HOST="${SOURCE_USER}@${SOURCE_HOST}:"
	RSYNC_PORT="$SOURCE_PORT"
fi

if [ -n "$TARGET_HOST" ]; then
	RSYNC_TARGET_HOST="${TARGET_USER}@${TARGET_HOST}:"
	RSYNC_PORT="$TARGET_PORT"
fi

if [ -z "$TARGET_HOST" ] && [[ $(whoami) == 'root' ]]; then
	RSYNC_CHOWN="--chown=${TARGET_USER}:${TARGET_USER}"
fi

if [[ "$TARGET_DB_HOST" == *:* ]]; then
	TARGET_DB_PORT=$(echo "$TARGET_DB_HOST" | awk -F ':' '{print $2}')
	TARGET_DB_HOST=$(echo "$TARGET_DB_HOST" | awk -F ':' '{print $1}')
fi

# Create dir for logs if not exists
#
#if ! [ -d "$SCRIPT_LOGS_DIR" ]; then
#	mkdir $SCRIPT_LOGS_DIR
#fi

# Prepare SSH auth via password

if [[ -n "$SOURCE_HOST" && "$SOURCE_AUTH_TYPE" == "pass" ]] || [[ -n "$TARGET_HOST" && "$TARGET_AUTH_TYPE" == "pass" ]]; then
	touch "$SCRIPT_SSH_PASS_TMP"
	chmod 700 "$SCRIPT_SSH_PASS_TMP"
	export SSH_ASKPASS="$SCRIPT_SSH_PASS_TMP"
	export DISPLAY=:0.0
	SETSID="setsid"
	if [ -n "$SOURCE_HOST" ]; then
		echo "echo '${SOURCE_USER_PASS}'" > "$SCRIPT_SSH_PASS_TMP"
	else
		echo "echo '${TARGET_USER_PASS}'" > "$SCRIPT_SSH_PASS_TMP"
	fi
fi

# Prepare exclude list file for rsync

RSYNC_EXCLUDE_ARRAY=($RSYNC_EXCLUDE_LIST)

printf "%s\n" "${RSYNC_EXCLUDE_ARRAY[@]}" > "$RSYNC_EXCLUDE_LIST_FILE"

#for RSYNC_EXCLUDE_ARRAY_ITEM in "${RSYNC_EXCLUDE_ARRAY[@]}"; do
#	echo "$RSYNC_EXCLUDE_ARRAY_ITEM" >> "$RSYNC_EXCLUDE_LIST_FILE"
#done

# Checks

echo -n "Checking vars..."

if [ -n "$SOURCE_HOST" ] && [ -n "$TARGET_HOST" ]; then
	$SETCOLOR_FAILURE
	echo "[FAIL]"
	echo "The source and target hosts cannot both be remote!" 1>&2
	$SETCOLOR_NORMAL
	ERRORS_CHECK=1
	FAIL_BOTH_REMOTE=1
else
	$SETCOLOR_SUCCESS
	echo "[OK]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking current user..."

if [ -n "$SOURCE_HOST" ] && [ -z "$TARGET_HOST" ] && [[ $(whoami) != 'root' ]] && [[ $(whoami) != "$TARGET_USER" ]]; then
	$SETCOLOR_FAILURE
	echo "[FAIL]"
	echo "You must be root or $TARGET_USER on target host!" 1>&2
	$SETCOLOR_NORMAL
	ERRORS_CHECK=1
	FAIL_USER=1
elif [ -z "$SOURCE_HOST" ] && [ -z "$TARGET_HOST" ] && [[ "$SOURCE_USER" != "$TARGET_USER" ]] && [[ $(whoami) != 'root' ]]; then
	$SETCOLOR_FAILURE
	echo "[FAIL]"
	echo "You must be root!" 1>&2
	$SETCOLOR_NORMAL
	ERRORS_CHECK=1
	FAIL_USER=1
else
	$SETCOLOR_SUCCESS
	echo "[OK]"
	$SETCOLOR_NORMAL

fi

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ]; then
	if [ -n "$SOURCE_HOST" ] || [ -n "$TARGET_HOST" ]; then
		if [ -n "$SOURCE_HOST" ] && [[ "$SOURCE_AUTH_TYPE" == "key" ]]; then
			echo -n "Checking connection to source host via SSH key..."
			ssh -o batchmode=yes -o StrictHostKeyChecking=no "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "echo -n" 2>/dev/null
		elif [ -n "$TARGET_HOST" ] && [[ "$TARGET_AUTH_TYPE" == "key" ]]; then
			echo -n "Checking connection to target host via SSH key..."
			ssh -o batchmode=yes -o StrictHostKeyChecking=no "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "echo -n" 2>/dev/null
		elif [ -n "$SOURCE_HOST" ] && [[ "$SOURCE_AUTH_TYPE" == "pass" ]]; then
			echo -n "Checking connection to source host via password..."
			$SETSID ssh -o StrictHostKeyChecking=no "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "echo -n" 2>/dev/null
		elif [ -n "$TARGET_HOST" ] && [[ "$TARGET_AUTH_TYPE" == "pass" ]]; then
			echo -n "Checking connection to target host via password..."
			$SETSID ssh -o StrictHostKeyChecking=no "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "echo -n" 2>/dev/null
		fi

		if [ "$?" -eq 255 ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_REMOTE=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
		fi
	fi
fi

echo -n "Checking source TMP path..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ]; then
	if [ -z "$SOURCE_HOST" ]; then
		if ! [ -d "${TMPDIR-/tmp}" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't find directory for temporary files on source host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_TMP_PATH=1
		elif ! [ -w "${TMPDIR-/tmp}" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "User can't write to directory for temporary files on source host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_TMP_PATH=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
			SOURCE_TMP_PATH="${TMPDIR-/tmp}"
		fi
	else
		CHECK_REMOTE_SOURCE_TMP_PATH_EXISTS=$($SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "if [ -d \"\${TMPDIR-/tmp}\" ]; then echo \"\${TMPDIR-/tmp}\"; fi")
		CHECK_REMOTE_SOURCE_TMP_PATH_ACCESS=$($SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "if [ -w \"\${TMPDIR-/tmp}\" ]; then echo 'writable'; fi")

		if [ -z "$CHECK_REMOTE_SOURCE_TMP_PATH_EXISTS" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't find directory for temporary files on source host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_TMP_PATH=1
		elif [ -z "$CHECK_REMOTE_SOURCE_TMP_PATH_ACCESS" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "User can't write to directory for temporary files on source host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_TMP_PATH=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
			SOURCE_TMP_PATH="$CHECK_REMOTE_SOURCE_TMP_PATH_EXISTS"
		fi
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking target TMP path..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ]; then
	if [ -z "$TARGET_HOST" ]; then
		if ! [ -d "${TMPDIR-/tmp}" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't find directory for temporary files on target host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_TMP_PATH=1
		elif ! [ -w "${TMPDIR-/tmp}" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "User can't write to directory for temporary files on target host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_TMP_PATH=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
			TARGET_TMP_PATH="${TMPDIR-/tmp}"
		fi
	else
		CHECK_REMOTE_TARGET_TMP_PATH_EXISTS=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "if [ -d \"\${TMPDIR-/tmp}\" ]; then echo \"\${TMPDIR-/tmp}\"; fi")
		CHECK_REMOTE_TARGET_TMP_PATH_ACCESS=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "if [ -w \"\${TMPDIR-/tmp}\" ]; then echo 'writable'; fi")

		if [ -z "$CHECK_REMOTE_TARGET_TMP_PATH_EXISTS" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't find directory for temporary files on target host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_TMP_PATH=1
		elif [ -z "$CHECK_REMOTE_TARGET_TMP_PATH_ACCESS" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "User can't write to directory for temporary files on target host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_TMP_PATH=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
			TARGET_TMP_PATH="$CHECK_REMOTE_TARGET_TMP_PATH_EXISTS"
		fi
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking source WordPress installation..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ] && [ "$FAIL_TMP_PATH" -eq 0 ]; then
	if [ -z "$SOURCE_HOST" ] && ! [ -f "${SOURCE_PATH}/wp-config.php" ]; then
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		echo "Not found WordPress installation in source path!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
		FAIL_WP=1
	elif [ -z "$SOURCE_HOST" ] && [ -f "${SOURCE_PATH}/wp-config.php" ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		SOURCE_WP_CONFIG_CHECK=$($SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "ls \"${SOURCE_PATH}\"/wp-config.php 2>/dev/null" 2>/dev/null)
		if [ "$?" -eq 255 ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't connect to source remote host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_WP=1
		elif [[ "$SOURCE_WP_CONFIG_CHECK" != "${SOURCE_PATH}/wp-config.php" ]]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Not found WordPress installation in source path on remote host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_WP=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
		fi
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking WordPress credentials..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ] && [ "$FAIL_TMP_PATH" -eq 0 ] && [ "$FAIL_WP" -eq 0 ]; then
	if [ -z "$SOURCE_HOST" ]; then
		SOURCE_WP_CONFIG=$(cat "${SOURCE_PATH}"/wp-config.php)
	else
		SOURCE_WP_CONFIG=$($SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "cat \"${SOURCE_PATH}\"/wp-config.php" 2>/dev/null)
	fi

	if [ "$?" -eq 255 ] && [ -n "$SOURCE_HOST" ]; then
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		echo "Can't connect to source remote host!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
		FAIL_SOURCE_DB=1
	else
		SOURCE_DB_HOST=$(echo "$SOURCE_WP_CONFIG" | grep '^\s*define.*DB_HOST' | tail -n 1 | awk -F',' '{print $2}' | sed "s/^[^']*'//" | sed "s/'[^']*//" | sed 's/^[^"]*"//' | sed 's/"[^"]*//')
		SOURCE_DB_NAME=$(echo "$SOURCE_WP_CONFIG" | grep '^\s*define.*DB_NAME' | tail -n 1 | awk -F',' '{print $2}' | sed "s/^[^']*'//" | sed "s/'[^']*//" | sed 's/^[^"]*"//' | sed 's/"[^"]*//')
		SOURCE_DB_USER=$(echo "$SOURCE_WP_CONFIG" | grep '^\s*define.*DB_USER' | tail -n 1 | awk -F',' '{print $2}' | sed "s/^[^']*'//" | sed "s/'[^']*//" | sed 's/^[^"]*"//' | sed 's/"[^"]*//')
		SOURCE_DB_PASS=$(echo "$SOURCE_WP_CONFIG" | grep '^\s*define.*DB_PASSWORD' | tail -n 1 | awk -F',' '{print $2}' | sed "s/^[^']*'//" | sed "s/'[^']*//" | sed 's/^[^"]*"//' | sed 's/"[^"]*//')
		SOURCE_DB_PREFIX=$(echo "$SOURCE_WP_CONFIG" | grep '^\s*\$table_prefix' | tail -n 1 | awk -F'=' '{print $2}' | sed "s/^[^']*'//" | sed "s/'[^']*//" | sed 's/^[^"]*"//' | sed 's/"[^"]*//')

		if [ -z "$SOURCE_DB_HOST" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't get DB host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_SOURCE_DB=1
		elif [ -z "$SOURCE_DB_NAME" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't get DB name!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_SOURCE_DB=1
		elif [ -z "$SOURCE_DB_USER" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't get DB user!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_SOURCE_DB=1
		elif [ -z "$SOURCE_DB_PASS" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't get DB user password!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_SOURCE_DB=1
		elif [ -z "$SOURCE_DB_PREFIX" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't get DB table prefix!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
			FAIL_SOURCE_DB=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL

			if [[ "$SOURCE_DB_HOST" == *:* ]]; then
				SOURCE_DB_PORT=$(echo "$SOURCE_DB_HOST" | awk -F ':' '{print $2}')
				SOURCE_DB_HOST=$(echo "$SOURCE_DB_HOST" | awk -F ':' '{print $1}')
			fi
		fi
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking source DB and get WP site URL..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ] && [ "$FAIL_TMP_PATH" -eq 0 ] && [ "$FAIL_WP" -eq 0 ] && [ "$FAIL_SOURCE_DB" -eq 0 ]; then
	if [ -z "$SOURCE_HOST" ]; then
		SOURCE_SITE_URL=$(mysql -h "$SOURCE_DB_HOST" -P "$SOURCE_DB_PORT" -u "$SOURCE_DB_USER" -p"$SOURCE_DB_PASS" -BN -e "select option_value from ${SOURCE_DB_NAME}.${SOURCE_DB_PREFIX}options where option_name='siteurl' ;" 2>&1)
	else
		SOURCE_SITE_URL=$($SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "mysql -h \"$SOURCE_DB_HOST\" -P \"$SOURCE_DB_PORT\" -u \"$SOURCE_DB_USER\" -p\"${SOURCE_DB_PASS}\" -BN -e \"select option_value from ${SOURCE_DB_NAME}.${SOURCE_DB_PREFIX}options where option_name='siteurl' ;\" 2>&1")
	fi

	SOURCE_SITE_URL=$(echo "$SOURCE_SITE_URL" | grep -v 'Using a password' | sed 's/\/$//')
	SOURCE_SITE_URL=$(echo "$SOURCE_SITE_URL" | grep -v 'Forcing protocol to' | sed 's/\/$//')

	if [ "$?" -eq 255 ] && [ -n "$SOURCE_HOST" ]; then
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		echo "Can't connect to source remote host!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ -z "$SOURCE_SITE_URL" ]; then
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		echo "Can't get WP site URL!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [[ "$SOURCE_SITE_URL" =~ "ERROR" ]]; then
		if [[ "$SOURCE_SITE_URL" =~ Table\ .*doesn\'t\ exist ]]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Table ${SOURCE_DB_PREFIX}options does not exists in $SOURCE_DB_NAME database!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		elif [[ "$SOURCE_SITE_URL" =~ "Access denied for user" ]]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Access to $SOURCE_DB_NAME denied for user $SOURCE_DB_USER!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		elif [[ "$SOURCE_SITE_URL" =~ "Unknown database" ]]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "DB $SOURCE_DB_NAME not exists!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		elif [[ "$SOURCE_SITE_URL" =~ "Can\'t connect" ]]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Can't connect to DB server on source host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		else
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Unknown error!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		fi
	elif [ $(checkUrlFormat "$SOURCE_SITE_URL") -eq 0 ]; then
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		echo "Wrong site URL!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	else
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking target host path..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ] && [ "$FAIL_TMP_PATH" -eq 0 ]; then
	if [ -z "$TARGET_HOST" ]; then
		if ! [ -d "$TARGET_PATH" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Directory $TARGET_PATH does not exists on target host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		elif ! [ -w "$TARGET_PATH" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "User can't write to $TARGET_PATH on target host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
		fi
	else
		CHECK_REMOTE_TARGET_PATH_EXISTS=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "if [ -d \"$TARGET_PATH\" ]; then echo 'exists'; fi")
		CHECK_REMOTE_TARGET_PATH_ACCESS=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "if [ -w \"$TARGET_PATH\" ]; then echo 'writable'; fi")

		if [ -z "$CHECK_REMOTE_TARGET_PATH_EXISTS" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Directory $TARGET_PATH does not exists on target host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		elif [ -z "$CHECK_REMOTE_TARGET_PATH_ACCESS" ]; then
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "User can't write to $TARGET_PATH on target host!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
		fi
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking target DB..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ] && [ "$FAIL_TMP_PATH" -eq 0 ]; then
	if [ -z "$TARGET_HOST" ]; then
		CHECK_TARGET_DB=$(mysql -h "$TARGET_DB_HOST" -P "$TARGET_DB_PORT" -u "$TARGET_DB_USER" -p"$TARGET_DB_PASS" -e "USE \"${TARGET_DB_NAME}\";" 2>&1)
	else
		CHECK_TARGET_DB=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "mysql -h \"$TARGET_DB_HOST\" -P \"$TARGET_DB_PORT\" -u \"$TARGET_DB_USER\" -p\"${TARGET_DB_PASS}\" -e \"USE \"${TARGET_DB_NAME}\";\" 2>&1" 2>&1)
	fi

	CHECK_TARGET_DB=$(echo "$CHECK_TARGET_DB" | grep -v 'Using a password')
	CHECK_TARGET_DB=$(echo "$CHECK_TARGET_DB" | grep -v 'Forcing protocol to')

	if [ "$?" -eq 255 ]; then
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		echo "Can't connect to source remote host!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ -n "$CHECK_TARGET_DB" ]; then
		if [[ "$CHECK_TARGET_DB" =~ "ERROR" ]]; then
			if [[ "$CHECK_TARGET_DB" =~ "Access denied for user" ]]; then
				$SETCOLOR_FAILURE
				echo "[FAIL]"
				echo "Access to $TARGET_DB_NAME denied for user $TARGET_DB_USER!" 1>&2
				$SETCOLOR_NORMAL
				ERRORS_CHECK=1
			elif [[ "$CHECK_TARGET_DB" =~ "Unknown database" ]]; then
				$SETCOLOR_FAILURE
				echo "[FAIL]"
				echo "DB $TARGET_DB_NAME not exists!" 1>&2
				$SETCOLOR_NORMAL
				ERRORS_CHECK=1
			elif [[ "$CHECK_TARGET_DB" =~ "Can\'t connect" ]]; then
				$SETCOLOR_FAILURE
				echo "[FAIL]"
				echo "Can't connect to DB server on target host!" 1>&2
				$SETCOLOR_NORMAL
				ERRORS_CHECK=1
			else
				$SETCOLOR_FAILURE
				echo "[FAIL]"
				echo "Unknown error!" 1>&2
				$SETCOLOR_NORMAL
				ERRORS_CHECK=1
			fi
		else
			$SETCOLOR_FAILURE
			echo "[FAIL]"
			echo "Unknown error!" 1>&2
			$SETCOLOR_NORMAL
			ERRORS_CHECK=1
		fi
	else
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking for WP-CLI on target host..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ] && [ "$FAIL_TMP_PATH" -eq 0 ]; then
	if [ -z "$TARGET_WPCLI_PATH" ]; then
		if [ -z "$TARGET_HOST" ]; then
			TARGET_WPCLI_PATH=$(type -p wp 2>/dev/null)
		else
			TARGET_WPCLI_PATH=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "type -p wp" 2>/dev/null)
		fi
	else
		if [ -z "$TARGET_HOST" ]; then
			TARGET_WPCLI_PATH=$(ls "$TARGET_WPCLI_PATH" 2>/dev/null)
		else
			TARGET_WPCLI_PATH=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "ls ${TARGET_WPCLI_PATH}" 2>/dev/null)
		fi
	fi

	if [ "$?" -eq 255 ]; then
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		echo "Can't connect to source remote host!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ -n "$TARGET_WPCLI_PATH" ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
		WPCLI="$TARGET_WPCLI_PATH"
	else
		$SETCOLOR_FAILURE
		echo "[NOT FOUND]"
		$SETCOLOR_NORMAL
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Checking for PHP on target host..."

if [ "$FAIL_BOTH_REMOTE" -eq 0 ] && [ "$FAIL_USER" -eq 0 ] && [ "$FAIL_REMOTE" -eq 0 ] && [ "$FAIL_TMP_PATH" -eq 0 ]; then
	if [ -z "$TARGET_PHP_PATH" ]; then
		if [ -z "$TARGET_HOST" ]; then
			TARGET_PHP_PATH=$(type -p php 2>/dev/null)
		else
			TARGET_PHP_PATH=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "type -p php" 2>/dev/null)
		fi
	else
		if [ -z "$TARGET_HOST" ]; then
			TARGET_PHP_PATH=$(ls "$TARGET_PHP_PATH" 2>/dev/null)
		else
			TARGET_PHP_PATH=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "ls ${TARGET_PHP_PATH}" 2>/dev/null)
		fi
	fi

	if [ "$?" -eq 255 ]; then
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		echo "Can't connect to source remote host!" 1>&2
		$SETCOLOR_NORMAL
		ERRORS_CHECK=1
	elif [ -n "$TARGET_PHP_PATH" ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
		PHP="$TARGET_PHP_PATH"
	else
		$SETCOLOR_FAILURE
		echo "[NOT FOUND]"
		$SETCOLOR_NORMAL
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo

if [ "$ERRORS_CHECK" -eq 1 ]; then
	cleanup "Cleanup and exit..."
	exit 1
fi

# Prepare migration vars

if [ -n "$SOURCE_DB_PASS" ]; then
	CMD_SOURCE_DB_PASS="-p${SOURCE_DB_PASS}"
fi

SOURCE_SCRIPT_ERRORS_TMP="${SOURCE_TMP_PATH}/zwp_migrate.tmp.errors.${SCRIPT_INSTANCE_KEY}"
TARGET_SCRIPT_ERRORS_TMP="${TARGET_TMP_PATH}/zwp_migrate.tmp.errors.${SCRIPT_INSTANCE_KEY}"

if [ "$TARGET_DB_PORT" -eq 3306 ]; then
	TARGET_DB_HOST_WP="$TARGET_DB_HOST"
else
	TARGET_DB_HOST_WP="${TARGET_DB_HOST}:${TARGET_DB_PORT}"
fi

# Total info

if [ "$NO_ASK" -eq 0 ]; then
	echo "${BOLD_TEXT}Check input data and confirm:${NORMAL_TEXT}"
	echo
fi

echo "${BOLD_TEXT}# SOURCE${NORMAL_TEXT}"
if [ -n "$SOURCE_HOST" ]; then
	echo "${BOLD_TEXT}Host:${NORMAL_TEXT} ${SOURCE_HOST} (port: ${SOURCE_PORT})"
else
	echo "${BOLD_TEXT}Host:${NORMAL_TEXT} localhost"
fi
echo "${BOLD_TEXT}User:${NORMAL_TEXT} ${SOURCE_USER}"
echo "${BOLD_TEXT}Path:${NORMAL_TEXT} ${SOURCE_PATH}"
echo "${BOLD_TEXT}WP URL:${NORMAL_TEXT} ${SOURCE_SITE_URL}"
echo "${BOLD_TEXT}DB host:${NORMAL_TEXT} ${SOURCE_DB_HOST} (port: ${SOURCE_DB_PORT})"
echo "${BOLD_TEXT}DB name:${NORMAL_TEXT} ${SOURCE_DB_NAME}"
echo "${BOLD_TEXT}DB user:${NORMAL_TEXT} ${SOURCE_DB_USER}"
echo "${BOLD_TEXT}TMP path:${NORMAL_TEXT} ${SOURCE_TMP_PATH}"
echo
echo "${BOLD_TEXT}# TARGET${NORMAL_TEXT}"
if [ -n "$TARGET_HOST" ]; then
	echo "${BOLD_TEXT}Host:${NORMAL_TEXT} ${TARGET_HOST} (port: ${TARGET_PORT})"
else
	echo "${BOLD_TEXT}Host:${NORMAL_TEXT} localhost"
fi
echo "${BOLD_TEXT}User:${NORMAL_TEXT} ${TARGET_USER}"
echo "${BOLD_TEXT}Path:${NORMAL_TEXT} ${TARGET_PATH}"
echo "${BOLD_TEXT}WP URL:${NORMAL_TEXT} ${TARGET_SITE_URL}"
echo "${BOLD_TEXT}DB host:${NORMAL_TEXT} ${TARGET_DB_HOST} (port: ${TARGET_DB_PORT})"
echo "${BOLD_TEXT}DB name:${NORMAL_TEXT} ${TARGET_DB_NAME}"
echo "${BOLD_TEXT}DB user:${NORMAL_TEXT} ${TARGET_DB_USER}"
echo "${BOLD_TEXT}TMP path:${NORMAL_TEXT} ${TARGET_TMP_PATH}"
echo -n "${BOLD_TEXT}WP-CLI path:${NORMAL_TEXT} "
if [ -n "$WPCLI" ]; then
	echo "${TARGET_WPCLI_PATH}"
else
	echo "not found (it will be temporary download before migration)"
fi
echo "${BOLD_TEXT}PHP path:${NORMAL_TEXT} ${TARGET_PHP_PATH}"
if [ -f "$RSYNC_EXCLUDE_LIST_FILE" ] && [ -n "$(cat $RSYNC_EXCLUDE_LIST_FILE)" ]; then
	echo
	echo "${BOLD_TEXT}File patterns to exclude:${NORMAL_TEXT}"
	cat "$RSYNC_EXCLUDE_LIST_FILE"
fi
echo

# Confirm

if [ "$NO_ASK" -eq 0 ]; then
	echo -n "Continue? [y/N] > "
	read -r CONFIRM
	if [[ "$CONFIRM" != "y" ]]; then
		echo

		cleanup "Cleanup and exit..."
		exit 0
	fi

	echo
fi

# Migrate

if [ -z "$WPCLI" ]; then
	echo -n "Downloading WP-CLI to target host..."

	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			su -l "${TARGET_USER}" -s /bin/bash -c "curl -s -o \"${TARGET_TMP_PATH}\"/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x \"${TARGET_TMP_PATH}\"/wp-cli.phar 2>/dev/null"
		else
			curl -s -o "${TARGET_TMP_PATH}"/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x "${TARGET_TMP_PATH}"/wp-cli.phar 2>/dev/null
		fi
	else
		$SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "curl -s -o \"${TARGET_TMP_PATH}\"/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && chmod +x \"${TARGET_TMP_PATH}\"/wp-cli.phar 2>/dev/null"
	fi

	if [ "$?" -eq 0 ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
		WPCLI="${TARGET_TMP_PATH}/wp-cli.phar"
		WPCLI_DOWNLOADED=1
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
fi

echo -n "Creating DB dump..."

if [ "$ERRORS_MIGRATE" -eq 0 ]; then
	if [ -z "$SOURCE_HOST" ]; then
		mysqldump --insert-ignore --skip-lock-tables --single-transaction=TRUE --add-drop-table --no-tablespaces -h "$SOURCE_DB_HOST" -P "$SOURCE_DB_PORT" -u "$SOURCE_DB_USER" "$CMD_SOURCE_DB_PASS" "$SOURCE_DB_NAME" 2>"$SOURCE_SCRIPT_ERRORS_TMP" | gzip -c > "${SOURCE_PATH}"/"${SOURCE_DB_NAME}".sql.gz
		RESULT_ERRORS=$(cat "$SOURCE_SCRIPT_ERRORS_TMP" | grep -v 'Using a password' 2>&1)
	else
		$SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "mysqldump --insert-ignore --skip-lock-tables --single-transaction=TRUE --add-drop-table --no-tablespaces -h \"$SOURCE_DB_HOST\" -P \"$SOURCE_DB_PORT\" -u \"$SOURCE_DB_USER\" \"$CMD_SOURCE_DB_PASS\" \"$SOURCE_DB_NAME\" 2>\"$SOURCE_SCRIPT_ERRORS_TMP\" | gzip -c > \"${SOURCE_PATH}\"/\"${SOURCE_DB_NAME}\".sql.gz"
		RESULT_ERRORS=$($SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "cat \"$SOURCE_SCRIPT_ERRORS_TMP\" | grep -v 'Using a password' 2>&1")
	fi

	RESULT_ERRORS=$(echo "$RESULT_ERRORS" | grep -v 'Forcing protocol to' 2>&1)

	if [ -z "$RESULT_ERRORS" ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Syncing..."

if [ "$ERRORS_MIGRATE" -eq 0 ]; then
	if [ -z "$SOURCE_HOST" ] && [ -z "$TARGET_HOST" ]; then
		$SETSID rsync -azq ${RSYNC_CHOWN} --chmod=D755,F644 --exclude-from="$RSYNC_EXCLUDE_LIST_FILE" --delete "${SOURCE_PATH}"/* "${TARGET_PATH}"/ 2>/dev/null
		SYNC_RESULT=$?
		$SETSID rsync -azq ${RSYNC_CHOWN} --chmod=D755,F644 --exclude-from="$RSYNC_EXCLUDE_LIST_FILE" "${SOURCE_PATH}"/.??* "${TARGET_PATH}"/ 2>/dev/null
	else
		$SETSID rsync -azq -e "ssh -p ${RSYNC_PORT}" ${RSYNC_CHOWN} --chmod=D755,F644 --exclude-from="$RSYNC_EXCLUDE_LIST_FILE" --delete "${RSYNC_SOURCE_HOST}${SOURCE_PATH}"/* "${RSYNC_TARGET_HOST}${TARGET_PATH}"/ 2>/dev/null
		SYNC_RESULT=$?
		$SETSID rsync -azq -e "ssh -p ${RSYNC_PORT}" ${RSYNC_CHOWN} --chmod=D755,F644 --exclude-from="$RSYNC_EXCLUDE_LIST_FILE" "${RSYNC_SOURCE_HOST}${SOURCE_PATH}"/.??* "${RSYNC_TARGET_HOST}${TARGET_PATH}"/ 2>/dev/null
	fi

	if [ "$SYNC_RESULT" -eq 0 ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Importing DB..."

if [ "$ERRORS_MIGRATE" -eq 0 ]; then
	if [ -z "$TARGET_HOST" ]; then
		gunzip -c "${TARGET_PATH}"/"${SOURCE_DB_NAME}".sql.gz | mysql -h "${TARGET_DB_HOST}" -P "${TARGET_DB_PORT}" -u "${TARGET_DB_USER}" "${CMD_TARGET_DB_PASS}" "${TARGET_DB_NAME}" 2>"$TARGET_SCRIPT_ERRORS_TMP"
		RESULT_ERRORS=$(cat "$TARGET_SCRIPT_ERRORS_TMP" | grep -v 'Using a password' 2>&1)
	else
		$SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "gunzip -c \"${TARGET_PATH}\"/\"${SOURCE_DB_NAME}\".sql.gz | mysql -h \"${TARGET_DB_HOST}\" -P \"$TARGET_DB_PORT\" -u \"${TARGET_DB_USER}\" \"${CMD_TARGET_DB_PASS}\" \"${TARGET_DB_NAME}\" 2>\"$TARGET_SCRIPT_ERRORS_TMP\""
		RESULT_ERRORS=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "cat \"$TARGET_SCRIPT_ERRORS_TMP\" | grep -v 'Using a password' 2>&1")
	fi

	RESULT_ERRORS=$(echo "$RESULT_ERRORS" | grep -v 'Forcing protocol to' 2>&1)

	if [ -z "$RESULT_ERRORS" ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Updating credentials in wp-config.php"

if [ "$ERRORS_MIGRATE" -eq 0 ]; then
	echo ":"

	echo -n "  DB_HOST..."

	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			DB_HOST_CHANGE=$(su -l "${TARGET_USER}" -s /bin/bash -c "\"$PHP\" \"$WPCLI\" config set DB_HOST \"$TARGET_DB_HOST_WP\" --type=constant --path=\"${TARGET_PATH}\" 2>/dev/null")
		else
			DB_HOST_CHANGE=$("$PHP" "$WPCLI" config set DB_HOST "$TARGET_DB_HOST_WP" --type=constant --path="${TARGET_PATH}" 2>/dev/null)
		fi
	else
		DB_HOST_CHANGE=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "\"$PHP\" \"$WPCLI\" config set DB_HOST \"$TARGET_DB_HOST_WP\" --type=constant --path=\"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [[ "$DB_HOST_CHANGE" =~ "Success:" ]]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi

	echo -n "  DB_NAME..."

	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			DB_NAME_CHANGE=$(su -l "${TARGET_USER}" -s /bin/bash -c "\"$PHP\" \"$WPCLI\" config set DB_NAME \"$TARGET_DB_NAME\" --type=constant --path=\"${TARGET_PATH}\" 2>/dev/null")
		else
			DB_NAME_CHANGE=$("$PHP" "$WPCLI" config set DB_NAME "$TARGET_DB_NAME" --type=constant --path="${TARGET_PATH}" 2>/dev/null)
		fi
	else
		DB_NAME_CHANGE=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "\"$PHP\" \"$WPCLI\" config set DB_NAME \"$TARGET_DB_NAME\" --type=constant --path=\"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [[ "$DB_NAME_CHANGE" =~ "Success:" ]]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi

	echo -n "  DB_USER..."

	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			DB_USER_CHANGE=$(su -l "${TARGET_USER}" -s /bin/bash -c "\"$PHP\" \"$WPCLI\" config set DB_USER \"$TARGET_DB_USER\" --type=constant --path=\"${TARGET_PATH}\" 2>/dev/null")
		else
			DB_USER_CHANGE=$("$PHP" "$WPCLI" config set DB_USER "$TARGET_DB_USER" --type=constant --path="${TARGET_PATH}" 2>/dev/null)
		fi
	else
		DB_USER_CHANGE=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "\"$PHP\" \"$WPCLI\" config set DB_USER \"$TARGET_DB_USER\" --type=constant --path=\"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [[ "$DB_USER_CHANGE" =~ "Success:" ]]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi

	echo -n "  DB_PASSWORD..."

	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			DB_PASS_CHANGE=$(su -l "${TARGET_USER}" -s /bin/bash -c "\"$PHP\" \"$WPCLI\" config set DB_PASSWORD \"$TARGET_DB_PASS\" --type=constant --path=\"${TARGET_PATH}\" 2>/dev/null")
		else
			DB_PASS_CHANGE=$("$PHP" "$WPCLI" config set DB_PASSWORD "$TARGET_DB_PASS" --type=constant --path="${TARGET_PATH}" 2>/dev/null)
		fi
	else
		DB_PASS_CHANGE=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "\"$PHP\" \"$WPCLI\" config set DB_PASSWORD \"$TARGET_DB_PASS\" --type=constant --path=\"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [[ "$DB_PASS_CHANGE" =~ "Success:" ]]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
else
	echo -n "..."
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Replacing URLs in DB..."

if [ "$ERRORS_MIGRATE" -eq 0 ] && [[ "$SOURCE_SITE_URL" != "$TARGET_SITE_URL" ]]; then
	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			REPLACING_RESULT=$(su -l "${TARGET_USER}" -s /bin/bash -c "\"$PHP\" \"$WPCLI\" search-replace \"$SOURCE_SITE_URL\" \"$TARGET_SITE_URL\" --all-tables --report-changed-only --path=\"${TARGET_PATH}\" 2>/dev/null")
		else
			REPLACING_RESULT=$("$PHP" "$WPCLI" search-replace "$SOURCE_SITE_URL" "$TARGET_SITE_URL" --all-tables --report-changed-only --path="${TARGET_PATH}" 2>/dev/null)
		fi
	else
		REPLACING_RESULT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "\"$PHP\" \"$WPCLI\" search-replace \"$SOURCE_SITE_URL\" \"$TARGET_SITE_URL\" --all-tables --report-changed-only --path=\"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [[ "$REPLACING_RESULT" =~ "Success:" ]]; then
		REPLACEMENTS=$(echo "$REPLACING_RESULT" | grep "Success:" | sed 's/.*Made \([0-9]\+\) replacement.*/\1/')
		if [[ "$REPLACEMENTS" =~ ^[0-9]+$ ]]; then
			if [ "$REPLACEMENTS" -gt 0 ]; then
				$SETCOLOR_SUCCESS
				echo "[OK - replacements: ${REPLACEMENTS}]"
				$SETCOLOR_NORMAL
			else
				$SETCOLOR_SUCCESS
				echo "[OK - no replacements]"
				$SETCOLOR_NORMAL
			fi
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
		fi
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Replacing paths in DB..."

if [ "$ERRORS_MIGRATE" -eq 0 ] && [[ "$SOURCE_PATH" != "$TARGET_PATH" ]]; then
	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			REPLACING_RESULT=$(su -l "${TARGET_USER}" -s /bin/bash -c "\"$PHP\" \"$WPCLI\" search-replace \"$SOURCE_PATH\" \"$TARGET_PATH\" --all-tables --report-changed-only --path=\"${TARGET_PATH}\" 2>/dev/null")
		else
			REPLACING_RESULT=$("$PHP" "$WPCLI" search-replace "$SOURCE_PATH" "$TARGET_PATH" --all-tables --report-changed-only --path="${TARGET_PATH}" 2>/dev/null)
		fi
	else
		REPLACING_RESULT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "\"$PHP\" \"$WPCLI\" search-replace \"$SOURCE_PATH\" \"$TARGET_PATH\" --all-tables --report-changed-only --path=\"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [[ "$REPLACING_RESULT" =~ "Success:" ]]; then
		REPLACEMENTS=$(echo "$REPLACING_RESULT" | grep "Success:" | sed 's/.*Made \([0-9]\+\) replacement.*/\1/')
		if [[ "$REPLACEMENTS" =~ ^[0-9]+$ ]]; then
			if [ "$REPLACEMENTS" -gt 0 ]; then
				$SETCOLOR_SUCCESS
				echo "[OK - replacements: ${REPLACEMENTS}]"
				$SETCOLOR_NORMAL
			else
				$SETCOLOR_SUCCESS
				echo "[OK - no replacements]"
				$SETCOLOR_NORMAL
			fi
		else
			$SETCOLOR_SUCCESS
			echo "[OK]"
			$SETCOLOR_NORMAL
		fi
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Replacing URLs in files..."

if [ "$ERRORS_MIGRATE" -eq 0 ] && [[ "$SOURCE_SITE_URL" != "$TARGET_SITE_URL" ]]; then
	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			FILES_FOR_REPLACEMENT=$(su -l "${TARGET_USER}" -s /bin/bash -c "grep -lr \"$SOURCE_SITE_URL\" \"${TARGET_PATH}\" 2>/dev/null")
		else
			FILES_FOR_REPLACEMENT=$(grep -lr "$SOURCE_SITE_URL" "${TARGET_PATH}" 2>/dev/null)
		fi
	else
		FILES_FOR_REPLACEMENT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "grep -lr \"$SOURCE_SITE_URL\" \"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [ -n "$FILES_FOR_REPLACEMENT" ]; then
		FILES_FOR_REPLACEMENT_CHECK=$(echo "$FILES_FOR_REPLACEMENT" | grep "$TARGET_PATH" 2>/dev/null)

		if [ -n "$FILES_FOR_REPLACEMENT_CHECK" ]; then
			if [ -z "$TARGET_HOST" ]; then
				if [[ $(whoami) == 'root' ]]; then
					FILES_FOR_REPLACEMENT_COUNT=$(su -l "${TARGET_USER}" -s /bin/bash -c "echo \"$FILES_FOR_REPLACEMENT\" | wc -l 2>/dev/null")
					REPLACING_RESULT=$(su -l "${TARGET_USER}" -s /bin/bash -c "echo \"$FILES_FOR_REPLACEMENT\" | xargs sed -i \"s|${SOURCE_SITE_URL}|${TARGET_SITE_URL}|g\" 2>/dev/null")
					CHECK_FILES=$(su -l "${TARGET_USER}" -s /bin/bash -c "grep -lr \"$SOURCE_SITE_URL\" \"${TARGET_PATH}\" | wc -l 2>/dev/null")
				else
					FILES_FOR_REPLACEMENT_COUNT=$(echo "$FILES_FOR_REPLACEMENT" | wc -l 2>/dev/null)
					REPLACING_RESULT=$(echo "$FILES_FOR_REPLACEMENT" | xargs sed -i "s|${SOURCE_SITE_URL}|${TARGET_SITE_URL}|g" 2>/dev/null)
					CHECK_FILES=$(grep -lr \"$SOURCE_SITE_URL\" \"${TARGET_PATH}\" | wc -l 2>/dev/null)
				fi
			else
				FILES_FOR_REPLACEMENT_COUNT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "echo \"$FILES_FOR_REPLACEMENT\" | wc -l 2>/dev/null")
				REPLACING_RESULT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "echo \"$FILES_FOR_REPLACEMENT\" | xargs sed -i \"s|${SOURCE_SITE_URL}|${TARGET_SITE_URL}|g\" 2>/dev/null")
				CHECK_FILES=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "grep -lr \"$SOURCE_SITE_URL\" \"${TARGET_PATH}\" | wc -l 2>/dev/null")
			fi

			if [ "$CHECK_FILES" -eq 0 ]; then
				$SETCOLOR_SUCCESS
				echo "[OK - modified files: ${FILES_FOR_REPLACEMENT_COUNT}]"
				$SETCOLOR_NORMAL
			else
				$SETCOLOR_FAILURE
				echo "[FAIL - unable to modify one or more files]"
				$SETCOLOR_NORMAL
				ERRORS_MIGRATE=1
			fi
		else
			$SETCOLOR_FAILURE
			echo "[FAIL - wrong list of files for replacements]"
			$SETCOLOR_NORMAL
			ERRORS_MIGRATE=1
		fi
	else
		$SETCOLOR_GREY
		echo "[SKIPPING - no found files for replacement]"
		$SETCOLOR_NORMAL
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "Replacing paths in files..."

if [ "$ERRORS_MIGRATE" -eq 0 ] && [[ "$SOURCE_PATH" != "$TARGET_PATH" ]]; then
	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			FILES_FOR_REPLACEMENT=$(su -l "${TARGET_USER}" -s /bin/bash -c "grep -lr \"$SOURCE_PATH\" \"${TARGET_PATH}\" 2>/dev/null")
		else
			FILES_FOR_REPLACEMENT=$(grep -lr "$SOURCE_PATH" "${TARGET_PATH}" 2>/dev/null)
		fi
	else
		FILES_FOR_REPLACEMENT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "grep -lr \"$SOURCE_PATH\" \"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [ -n "$FILES_FOR_REPLACEMENT" ]; then
		FILES_FOR_REPLACEMENT_CHECK=$(echo "$FILES_FOR_REPLACEMENT" | grep "$TARGET_PATH" 2>/dev/null)

		if [ -n "$FILES_FOR_REPLACEMENT_CHECK" ]; then
			if [ -z "$TARGET_HOST" ]; then
				if [[ $(whoami) == 'root' ]]; then
					FILES_FOR_REPLACEMENT_COUNT=$(su -l "${TARGET_USER}" -s /bin/bash -c "echo \"$FILES_FOR_REPLACEMENT\" | wc -l 2>/dev/null")
					REPLACING_RESULT=$(su -l "${TARGET_USER}" -s /bin/bash -c "echo \"$FILES_FOR_REPLACEMENT\" | xargs sed -i \"s|${SOURCE_PATH}|${TARGET_PATH}|g\" 2>/dev/null")
					CHECK_FILES=$(su -l "${TARGET_USER}" -s /bin/bash -c "grep -lr \"$SOURCE_PATH\" \"${TARGET_PATH}\" | wc -l 2>/dev/null")
				else
					FILES_FOR_REPLACEMENT_COUNT=$(echo "$FILES_FOR_REPLACEMENT" | wc -l 2>/dev/null)
					REPLACING_RESULT=$(echo "$FILES_FOR_REPLACEMENT" | xargs sed -i "s|${SOURCE_PATH}|${TARGET_PATH}|g" 2>/dev/null)
					CHECK_FILES=$(grep -lr \"$SOURCE_PATH\" \"${TARGET_PATH}\" | wc -l 2>/dev/null)
				fi
			else
				FILES_FOR_REPLACEMENT_COUNT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "echo \"$FILES_FOR_REPLACEMENT\" | wc -l 2>/dev/null")
				REPLACING_RESULT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "echo \"$FILES_FOR_REPLACEMENT\" | xargs sed -i \"s|${SOURCE_PATH}|${TARGET_PATH}|g\" 2>/dev/null")
				CHECK_FILES=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "grep -lr \"$SOURCE_PATH\" \"${TARGET_PATH}\" | wc -l 2>/dev/null")
			fi

			if [ "$CHECK_FILES" -eq 0 ]; then
				$SETCOLOR_SUCCESS
				echo "[OK - modified files: ${FILES_FOR_REPLACEMENT_COUNT}]"
				$SETCOLOR_NORMAL
			else
				$SETCOLOR_FAILURE
				echo "[FAIL - unable to modify one or more files]"
				$SETCOLOR_NORMAL
				ERRORS_MIGRATE=1
			fi
		else
			$SETCOLOR_FAILURE
			echo "[FAIL - wrong list of files for replacements]"
			$SETCOLOR_NORMAL
			ERRORS_MIGRATE=1
		fi
	else
		$SETCOLOR_GREY
		echo "[SKIPPING - no found files for replacement]"
		$SETCOLOR_NORMAL
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo "Cleanup:"

echo -n "  flushing wp cache..."

if [ "$ERRORS_MIGRATE" -eq 0 ]; then
	if [ -z "$TARGET_HOST" ]; then
		if [[ $(whoami) == 'root' ]]; then
			WP_FLUSH_CACHE_RESULT=$(su -l "${TARGET_USER}" -s /bin/bash -c "\"$PHP\" \"$WPCLI\" cache flush --path=\"${TARGET_PATH}\" 2>/dev/null")
		else
			WP_FLUSH_CACHE_RESULT=$("$PHP" "$WPCLI" cache flush --path="${TARGET_PATH}" 2>/dev/null)
		fi
	else
		WP_FLUSH_CACHE_RESULT=$($SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "\"$PHP\" \"$WPCLI\" cache flush --path=\"${TARGET_PATH}\" 2>/dev/null")
	fi

	if [[ "$WP_FLUSH_CACHE_RESULT" =~ "Success:" ]]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
else
	$SETCOLOR_GREY
	echo "[SKIPPING]"
	$SETCOLOR_NORMAL
fi

echo -n "  removing source DB dump..."

if [ -z "$SOURCE_HOST" ]; then
	rm "${SOURCE_PATH}"/"${SOURCE_DB_NAME}".sql.gz > /dev/null 2>/dev/null
else
	$SETSID ssh "${SOURCE_USER}"@"${SOURCE_HOST}" -p "${SOURCE_PORT}" "rm \"${SOURCE_PATH}\"/\"${SOURCE_DB_NAME}\".sql.gz > /dev/null 2>/dev/null" > /dev/null 2>/dev/null
fi

if [ "$?" -eq 0 ]; then
	$SETCOLOR_SUCCESS
	echo "[OK]"
	$SETCOLOR_NORMAL
else
	$SETCOLOR_FAILURE
	echo "[FAIL]"
	$SETCOLOR_NORMAL
	ERRORS_MIGRATE=1
fi

echo -n "  removing target DB dump..."

if [ -z "$TARGET_HOST" ]; then
	rm "${TARGET_PATH}"/"${SOURCE_DB_NAME}".sql.gz > /dev/null 2>/dev/null
else
	$SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "rm \"${TARGET_PATH}\"/\"${SOURCE_DB_NAME}\".sql.gz > /dev/null 2>/dev/null" > /dev/null 2>/dev/null
fi

if [ "$?" -eq 0 ]; then
	$SETCOLOR_SUCCESS
	echo "[OK]"
	$SETCOLOR_NORMAL
else
	$SETCOLOR_FAILURE
	echo "[FAIL]"
	$SETCOLOR_NORMAL
	ERRORS_MIGRATE=1
fi

if [ "$WPCLI_DOWNLOADED" -eq 1 ]; then
	echo -n "  removing WP-CLI from target host..."

	if [ -z "$TARGET_HOST" ]; then
		rm "$WPCLI" > /dev/null 2>/dev/null
	else
		$SETSID ssh "${TARGET_USER}"@"${TARGET_HOST}" -p "${TARGET_PORT}" "rm \"$WPCLI\" > /dev/null 2>/dev/null" > /dev/null 2>/dev/null
	fi

	if [ "$?" -eq 0 ]; then
		$SETCOLOR_SUCCESS
		echo "[OK]"
		$SETCOLOR_NORMAL
	else
		$SETCOLOR_FAILURE
		echo "[FAIL]"
		$SETCOLOR_NORMAL
		ERRORS_MIGRATE=1
	fi
fi

cleanup

exit "$ERRORS_MIGRATE"
