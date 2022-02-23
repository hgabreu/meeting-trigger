#!/bin/bash
set -o nounset
set -o noclobber
set -o errexit
shopt -qs inherit_errexit

declare -r VERSION=1.0.0-dev
declare -r CONFIG_FILE="${HOME}/.config/meeting-trigger/meeting-trigger.conf"

# New feature ideas list:
# - add "sensitivity" option to trigger every time an app starts/stops reading the mic
# - add "monitoredList" option to trigger only for certain apps (reverse logic of ignoreList)

# Prints usage help info to STDOUT
usage () {
	echo "meeting-trigger $VERSION

Usage:
  meeting-trigger [-v]
  meeting-trigger {-h --help}
  meeting-trigger {-V --version}
  meeting-trigger [-v] {ACTION} [parameters]

Actions:
  EditConfig [customEditor] [customEditorArgument]...
  ListAppsUsingMic
  Trigger {on off}
  TestAndTrigger

Options:
  -v  enable DEBUG messages to STDERR

meeting-trigger monitors a running PulseAudio server and checks for applications reading the mic.
When a change in state is detected (mic-in-use <> not-in-use) then custom scripts are triggered.

Check your config (EditConfig action) to see (and adjust) the triggers scripts directory.
Customize the sample trigger scripts (provided in that directory) to suit your needs.

Config file located at:
  $CONFIG_FILE

To enable meeting-trigger to run as a systemd service execute the following (no need for sudo):
  systemctl --user enable meeting-trigger
  systemctl --user start meeting-trigger
"
}

# Prints an initial configuration file to STDOUT
printTemplateConfigurationFile () {
	echo '# Configuration file for meeting-trigger
# ======================================================================

# Created by meeting-trigger '$VERSION'

# Application names to ignore (i.e. they use the mic, but you do not want to run the triggers for them):
ignoreList=()
#ignoreList+=("qemu-system-x86_64") #example of adding an application to the ignore list
# Use the ListAppsUsingMic to check which apps are using your mic at the moment

# Directory that holds scripts that will be called when the mic changes state (or following the forced trigger rules below)
# Check this directory for sample scripts and customize them to your needs
triggerDir="${HOME}/.config/meeting-trigger/scripts"

# Sets whether to call triggers when monitoring first starts
# Valid options are: on-only; off-only; both; none
# Default is "on-only", which makes an initial trigger only if the mic is being used right at boot
triggerInitialState="on-only"

# How long the main loop should sleep before polling again
pollingInterval="5s"

# Polls count that the system must trigger (on or off) even if the mic state has not changed
# Default is 0, which disables this forced triggering
# Use "1" to force a trigger for every poll
# To force a trigger every 15min, for example: 15*60sec/pollingInterval (say 5s) = 180
forceTriggerInterval=0

# Sets the forced trigger type (from above interval)
# Valid options are: on-only; off-only; both
# To disable it, set the interval above to 0
forceTriggerType="both"

# Whether to print DEBUG messages to STDERR
verbose=false
'
}

# Prints sample action script to STDOUT
printSampleScript () {
	echo '#!/bin/bash

# Sample meeting-trigger script action
# Feel free to delete or change this for your own use
# sample.sh {on off} [-v] [app1] [app2] ...

# Check for -v flag and set internal verbose variable
[ $# -gt 1 ] && [ "$2" = "-v" ] && verbose=true || verbose=false

if $verbose; then
	echo "Sample script running with arguments:"
	for i in $(seq 1 $#); do
		echo "\$$i='"'"'${!i}'"'"'"
	done
fi

if [ "$1" = "on" ]; then
	# do something when mic is on
	echo -n "Mic is in use"

	if $verbose && [ $# -gt 2 ]; then
		shift 2
		echo -n " by these apps: $@"
	fi
	echo

else # assuming off
	# do something when mic is no longer in use
	echo "Mic is NOT in use"
fi
'
}

# Prints sample ifttt.com script to STDOUT
printSampleIfttt () {
	echo '#!/bin/bash

# Sample Meeting-trigger ifttt.com webhook action call
# ifttt.sh {on off} [-v] [app1] [app2] ...

# Create your applets with a webhook trigger and setup your markers events name ending with an "on" or "off" suffix
# Example:
# Create an webhook-triggered applet (no json) for the marker event: lights_on
# Then another applet for the marker event: lights_off
event_basename="lights_"

# Then open: https://ifttt.com/maker_webhooks
# Click on the "Documentation" link, which should show your private webhook key
webhook_key="put your key here"

# Delete or comment the following line to "enable" this script action
exit 0

# Check verbose flag to redirect curl output
[ $# -gt 1 ] && [ "$2" = "-v" ] && exec 3>&1 || exec 3>/dev/null

# Actual webhook call. Concatenating the event_basename with the on/off parameter from the arguments
curl -s "https://maker.ifttt.com/trigger/${event_basename}$1/with/key/${webhook_key}" >&3

echo >&3 # adding a line-break because ifttt does not have one
'
}

# Sources CONFIG_FILE
loadSettingsFromConfigFile () {
	reloadConfig=false
	if [ -f "$CONFIG_FILE" ]; then
		# shellcheck source=/dev/null
		source -- "$CONFIG_FILE" && exitCode=$? || exitCode=$?
		if test "$exitCode" -ne 0; then
			echo "ERROR  Could not source configuration file \"$CONFIG_FILE\"" >&2
			exit "$exitCode"
		fi
		configFilesMonitored["$CONFIG_FILE"]="$(getFileStatus "$CONFIG_FILE")"
	else
		echo " WARN  Config file not found \"$CONFIG_FILE\"" >&2
	fi
}

# getFileStatus pathToFile
#
# Prints a status string for the given file composed of the file's size in bytes
# and its modification time in seconds since Epoch, separated by a single blank
# Prints nothing if the file does not exist
getFileStatus () {
	local file="$1"; shift
	local fileSizeBytes
	local fileModTime

	if test -e "$file"; then
		if ! fileSizeBytes="$(getFileSizeBytes "$file")" 2> /dev/null; then
			fileSizeBytes=""
		fi
		if ! fileModTime="$(getFileModTimeSecsSinceEpoch "$file")" 2> /dev/null; then
			fileModTime=""
		fi
		echo "$fileSizeBytes $fileModTime"
	fi
}

# getFileSizeBytes pathToFile
#
# Prints the given file's size, in bytes
getFileSizeBytes () {
	LC_ALL=C stat -c '%s' "$1"
}

# getFileModTimeSecsSinceEpoch pathToFile
#
# Prints the given file's modification time, in seconds since Epoch,
# with greatest possible decimal precision, using the dot "." as decimal
# separator
getFileModTimeSecsSinceEpoch () {
	# Force locale "C" to make stat use the dot as decimal separator
	LC_ALL=C stat -c '%.Y' "$1"
}

# Validates settings
validateSettings () {
	if ! [ -d "$triggerDir" ]; then
		echo " WARN  \$triggerDir is not a valid directory: $triggerDir" >&2
	fi

	local s="$triggerInitialState"
	if [ "$s" != "both" -a "$s" != "on-only" -a "$s" != "off-only" -a "$s" != "none" ]; then
		echo " WARN  \$triggerInitialState must be one of: both; on-only; off-only; none, but was \"$s\", using \"on-only\" instead" >&2
		triggerInitialState="on-only"
	fi

	# checking with sleep directly to see if it likes the pollingInterval
	sleep "$pollingInterval" 2>/dev/null & sleepPid=$!
	sleep 0 # yield, i.e. give the background job a chance to run
	if ! [ -e /proc/$sleepPid ]; then # Has sleep already terminated?
		if ! wait $sleepPid; then # so let's check if it indeed failed
			echo " WARN  Invalid \$pollingInterval, see \"sleep --help\" for valid options. Was \"$pollingInterval\", using \"5s\" instead" >&2
			pollingInterval="5s"
		else # not failed but finished in a few milliseconds?
			echo " WARN  \$pollingInterval is likely too small, are you sure \"$pollingInterval\" is correct?" >&2
		fi
	else # it looks like it worked
		kill -s TERM "$sleepPid" 2>/dev/null || true
	fi
	sleepPid=""

	if ! [ $forceTriggerInterval -ge 0 ] 2>/dev/null; then
		echo " WARN  \$forceTriggerInterval must be a non-negative integer, was \"$forceTriggerInterval\", using \"0\" instead" >&2
		forceTriggerInterval=0
	fi

	s="$forceTriggerType"
	if [ "$s" != "both" -a "$s" != "on-only" -a "$s" != "off-only" ]; then
		echo " WARN  \$forceTriggerType must be one of: both; on-only; off-only, but was \"$s\", using \"both\" instead" >&2
		forceTriggerType="both"
	fi

	if [ "$verbose" != "true" -a "$verbose" != "false" ]; then
		echo " WARN  \$verbose must be either \"true\" or \"false\", was \"$verbose\", using \"false\" instead" >&2
		verbose=false
	fi
}

# (Re)loads the configuration and validates the resulting settings
reloadConfig() {
	reloadConfig=false
	setDefaultSettings
	loadSettingsFromConfigFile
	validateSettings
}

isReloadRequired () {
	$reloadConfig || isUserConfigurationModified
}

# Returns with code 0 if the size or modification time of any of the files in
# $configFilesMonitored (associative array) have changed since the last call of reloadConfig()
isUserConfigurationModified () {
	local configFile

	for configFile in "${!configFilesMonitored[@]}"; do
		if test "${configFilesMonitored["$configFile"]}" != "$(getFileStatus "$configFile")"; then
			return 0
		fi
	done
	return 1
}

# Immediately resumes the main loop if it is waiting on its "sleep" call
resumeMainLoop () {
	local sleepPidCopy="$sleepPid"

	if test "$sleepPidCopy" != ""; then
		kill -s TERM "$sleepPidCopy" 2> /dev/null || true
	fi
}

# Sets the "stop" flag and immediately resumes the main loop if it is
# waiting on its "sleep" call
stop () {
	echo " INFO  Terminating main loop" >&2
	stopped=true
	resumeMainLoop
}

# Reloads the application configuration
#
# Immediately resumes the main loop if it is waiting on its "sleep" call
# (handler/trap function for signals that should cause a configuration reload)
handleSignalReloadConfig () {
	$verbose && echo "DEBUG  Reloading configuration" >&2
	reloadConfig=true
	resumeMainLoop
}

# Sets the "stop" flag
handleExit () {
	$verbose && echo "DEBUG  HandleExit" >&2
	stopped=true
}

# Attempts to acquire the instance lock to have only a single meeting-trigger per user at once
# Returns with code 0 if the lock has been acquired
getInstanceLock() {
	local pid=$$
	local pidFileNew
	local pidFromFile

	# Get the current PID file
	if ! pidFileNew="$(getPidFile)" || test "$pidFileNew" = ""; then
		echo "ERROR  Unable to determine the current PID file's path" >&2
		return 1
	fi

	# Try to obtain the lock
	if writePidFile "$pid" "$pidFileNew"; then
		# PID file did not exist and has been written successfully
		pidFile="$pidFileNew"
		return 0
	elif pidFromFile="$(getPidFromFile "$pidFileNew")"; then
		# PID file exists
		if test "$pidFromFile" = "$pid"; then
			# This is our PID file, we already have the lock
			pidFile="$pidFileNew"
			return 0
		else
			# Other PID or bullshit in file
			if kill -0 -- "$pidFromFile" 2> /dev/null; then
				# There is a process with the PID in this file: Somebody else has the lock
				return 1
			else
				# No process found that uses the PID from the file
				echo " WARN  Deleting stale PID file containing PID \"$pidFromFile\": \"$pidFileNew\"" >&2
				if test -f "$pidFileNew"; then
					rm -f "$pidFileNew" 2> /dev/null || true
				fi
				if writePidFile "$pid" "$pidFileNew"; then
					pidFile="$pidFileNew"
					return 0
				else
					return 1
				fi
			fi
		fi
	else
		# Something else
		#  - File could not be read
		#  - Race where the file has been deleted while this function was running
		return 1
	fi
}

# Prints the path of the pidFile
getPidFile () {
	if ! pidFileDir="$(getPidFileDir)" || test "$pidFileDir" = ""; then
		echo "ERROR  Unable to determine the PID file parent directory" >&2
		return 1
	fi
	echo "${pidFileDir}/meeting-trigger.pid"
}

getPidFileDir () {
	local baseDir

	if ! test -z ${XDG_RUNTIME_DIR+x} && test -d "$XDG_RUNTIME_DIR"; then
		echo "$XDG_RUNTIME_DIR"/meeting-trigger
		return 0
	fi
	if baseDir="/run/user/$(id -u)" && test -d "$baseDir"; then
		echo "$baseDir"/meeting-trigger
		return 0
	fi
	return 1
}

# getPidFromFile path
#
# Prints the first max. 40 characters of the given file's first text
# text line to STDOUT, terminated by a line break
# Non-digit characters are replaced by underscores
# Prints nothing and returns with code 1 if the file does not exist
# Prints nothing and returns with code 0 if the file is empty
getPidFromFile () {
	local path="$1"; shift
	local pid

	if ! test -f "$path"; then
		return 1
	fi
	while read -rsn 40 pid || test "$pid" != ""; do
		break
	done < <(cat "$path")
	if ! test -z ${pid+x}; then
		echo "$pid" | sed -re 's/[^0-9]/_/g'
	fi
}

# writePidFile pid filePath
#
# Writes the given PID followed by a line break to the given file if no
# such file exists
# Returns with code 0 if the file has been written
# ASSUMES THAT THE SHELL OPTION "noclobber" IS SET!
writePidFile () {
	local pid="$1"; shift
	local path="$1"; shift
	local parentPath

	# This test is technically not required as the "noclobber" shell
	# option atomically prevents an existing lock file from being overwritten
	# Its sole reason for existence is that, in the majority of cases,
	# it prevents the shell's error message about an attempt to clobber
	# an existing file, which can not easily be silenced
	if test -e "$path"; then
		return 1
	fi

	parentPath="$(dirname "$path")"
	mkdir --parents "$parentPath"
	echo "$pid" > "$path" 2> /dev/null
}

# Print apps' names using the mic to STDOUT
listAppsUsingMic () {
	pacmd list-source-outputs|grep 'application.name ='|cut -d'"' -f2
}

# Tests if appname provided as 1st argument is in ignoredList
isAppIgnored () {
	[[ ${ignoreList[*]} =~ (^|[[:space:]])"$1"($|[[:space:]]) ]]
}

# Print non ignored apps to STDOUT from list provided in STDIN
filterNonIgnoredApps () {
	while read -rs app; do
		isAppIgnored "$app" || echo "$app"
	done
}

# Special actions
# ----------------------------------------------------------------------

# runActionEditConfig [customEditor] [customEditorArgument]...
#
# Opens the primary configuration file in a text editor
# Creates a new configuration file if it does not exist yet
runActionEditConfig () {
	local editor

	# Find the text editor executable
	# shellcheck disable=SC2153  # $EDITOR is not a misspelling of $editor
	if test $# -gt 0; then
		editor="$1"; shift
	elif test ! -z ${EDITOR+x}; then
		editor="$EDITOR"
	else
		echo "ERROR  \$EDITOR is not set, please specify a text editor executable" >&2
		exit 1
	fi
	if ! type "$editor" &> /dev/null; then
		echo "ERROR  Text editor \"$editor\" does not exist or is not executable" >&2
		exit 1
	fi

	# Create a configuration file if it does not exist
	if ! test -e "$CONFIG_FILE"; then
		$verbose && echo "DEBUG  Configuration file does not exist, creating it" >&2
		# Create the configuration file's parent directories if they do not exist
		mkdir --parents "$(dirname "$CONFIG_FILE")"
		printTemplateConfigurationFile > "$CONFIG_FILE"
		# Create scripts dir
		mkdir --parents "$triggerDir"
		printSampleScript > "${triggerDir}/sample.sh"
		printSampleIfttt > "${triggerDir}/ifttt.sh"
		chmod u=rwx,go=rx "${triggerDir}"/{sample,ifttt}.sh
	fi

	# Launch the text editor with the arguments and the configuration file's path
	$verbose && echo "DEBUG  Launching text editor: \"$editor\" $* \"$CONFIG_FILE\"" >&2
	"$editor" "$@" "$CONFIG_FILE"
}

# runActionTrigger on/off
runActionTrigger () {
	if [ $# -eq 0 ] || [ "$1" != "on" -a "$1" != "off" ]; then
		echo "ERROR  Bad Trigger argument, \$1 one must be 'on' or 'off'. Check usage" >&2
		usage && exit 1
	fi

	local args=("--regex=.")
	$verbose && args+=("-v" "--arg=$1" "--arg=-v") || args+=("--arg=$1")

	shift;
	for app in "$@"; do
		args+=("--arg=$app")
	done

	$verbose && echo "DEBUG  run-parts ${args[@]} -- $triggerDir" >&2
	run-parts "${args[@]}" -- "$triggerDir" >&2
	forcedIntervalCounter=0
}

# Prints apps using the mic
runActionListAppsUsingMic() {
	$verbose && echo "DEBUG  Detecting mic state" >&2
	local len=0
	local apps=$(listAppsUsingMic)

	for app in $apps; do
		[ $len -lt ${#app} ] && len=${#app}
	done
	for app in $apps; do
		printf "%-${len}s - %s\n" "$app" "$(isAppIgnored $app && echo on Ignore list || echo using mic)"
	done
}

# Detects if state change and trigger actions accordingly
runActionTestAndTrigger () {
	$verbose && echo "DEBUG  Running test and trigger" >&2
	local apps=($(listAppsUsingMic | filterNonIgnoredApps))
	local newState=$([ ${#apps[@]} -gt 0 ] && echo on || echo off)

	$verbose && echo "DEBUG  currentState=$currentState; newState=$newState" >&2
	if [ "$newState" != "$currentState" ]; then
		currentState="$newState"
		runActionTrigger "$currentState" "${apps[*]}"

	elif [ $forceTriggerInterval -gt 0 ]; then
		((forcedIntervalCounter++)) || true
		if [ $forcedIntervalCounter -ge $forceTriggerInterval ]; then
			if [ "$forceTriggerType" = "both" ] ||
				[ "$forceTriggerType" = "on-only" -a "$currentState" = "on" ] ||
				[ "$forceTriggerType" = "off-only" -a "$currentState" = "off" ]; then

				$verbose && echo "DEBUG  Forcing trigger count $forcedIntervalCounter" >&2
				runActionTrigger "$currentState" "${apps[@]}"
			fi
		fi
	fi
}

# Sets/restores the default settings
setDefaultSettings () {
	# Applications reading from sources that should be ignored
	ignoreList=()
	
	# Directory with scripts to trigger [on|off]
	triggerDir="${HOME}/.config/meeting-trigger/scripts"

	# Whether to call trigger URLs when monitoring starts
	# Valid options are: on-only; off-only; both; none
	triggerInitialState="on-only"

	# How long the main loop should sleep before polling again
	pollingInterval="5s"

	# Polls count that the system must trigger (on or off) even if the mic state does not change
	forceTriggerInterval=0

	# Sets the forced trigger type (from above interval)
	forceTriggerType="both"

	# Whether to print DEBUG messages to STDERR
	verbose=false
}

# Basic startup checks
# ----------------------------------------------------------------------

# Make sure the required programs are available
allRequiredProgramsPresent=true
type cat &> /dev/null       || { echo 'ERROR  Required program "cat" is not available' >&2;       allRequiredProgramsPresent=false; }
type find &> /dev/null      || { echo 'ERROR  Required program "find" is not available' >&2;      allRequiredProgramsPresent=false; }
type grep &> /dev/null      || { echo 'ERROR  Required program "grep" is not available' >&2;      allRequiredProgramsPresent=false; }
type id &> /dev/null        || { echo 'ERROR  Required program "id" is not available' >&2;        allRequiredProgramsPresent=false; }
type kill &> /dev/null      || { echo 'ERROR  Required program "kill" is not available' >&2;      allRequiredProgramsPresent=false; }
type pacmd &> /dev/null     || { echo 'ERROR  Required program "pacmd" is not available' >&2;     allRequiredProgramsPresent=false; }
type run-parts &> /dev/null || { echo 'ERROR  Required program "run-parts" is not available' >&2; allRequiredProgramsPresent=false; }
type sed &> /dev/null       || { echo 'ERROR  Required program "sed" is not available' >&2;       allRequiredProgramsPresent=false; }
type stat &> /dev/null      || { echo 'ERROR  Required program "stat" is not available' >&2;      allRequiredProgramsPresent=false; }
$allRequiredProgramsPresent || exit 1
unset allRequiredProgramsPresent


# Global state variables
# ----------------------------------------------------------------------

# The config file(s) statuses to monitor for changes
declare -A configFilesMonitored
# Pre-load main config file to be picked up if it's created after started
configFilesMonitored["$CONFIG_FILE"]=""

# PID of the main loop's sleep process
sleepPid=""

# The path of the PID file for which the lock is currently being held
# (set to the empty string while not in possession of a lock)
pidFile=""

# True to leave the main loop and terminate
stopped=false

# True indicates the config must be (re)loaded
reloadConfig=true

# Current state ("on": mic's being used; "off": mic's not in use)
currentState=""

# Forced interval count
forcedIntervalCounter=0


# Handlers for special single arguments
# ----------------------------------------------------------------------

if [ $# -eq 1 ]; then
	if [ "$1" = "-h" -o "$1" = "--help" ]; then
		usage && exit 0
	elif [ "$1" = "-V" -o "$1" = "--version" ]; then
		echo "$VERSION" && exit 0
	fi
fi

# Apply/load and validate the settings
# ----------------------------------------------------------------------

reloadConfig
# set initial currentState depending on config to trigger (or not) initially
if [ "$triggerInitialState" = "none" ]; then
	currentState="$(runActionDetectMicState)"
elif [ "$triggerInitialState" = "on-only" ]; then
	currentState="off"
elif [ "$triggerInitialState" = "off-only" ]; then
	currentState="on"
else #assuming "both"
	currentState="initial"
fi

# Handler for special option "-v", for verbose
if [ $# -gt 0 ] && [ $1 = "-v" ]; then
	verbose=true; shift
fi

# Print an overview
# ----------------------------------------------------------------------

echo " INFO  This is meeting-trigger $VERSION" >&2;
$verbose && echo "DEBUG  Verbose output is enabled" >&2


# Handle special action if present
# ----------------------------------------------------------------------

# Returns with code 0 if the given command refers to a function
# (and not, for example, to a shell builtin or an executable)
isFunction () {
	local command="$1"; shift
	local commandType

	! commandType="$(type -t "$command")" && return 1
	! test "function" = "$commandType" && return 1
	return 0
}

# Run a special action instead of the regular daemon if such an action is provided
if [ $# -gt 0 ]; then
	action="$1"; shift

	if [ $# -gt 0 ] && [ "$1" = "-v" ]; then
		verbose=true; shift
	fi
	currentState="manual" # Allows for manual exectution of TestAndTrigger to always trigger on/off

	actionFunction="runAction$action"
	if isFunction "$actionFunction"; then
		$verbose && echo "DEBUG  Running action \"$action\" with $# argument(s)" >&2
		"$actionFunction" "$@" && returnCode="$?" || returnCode="$?"
		[ "$returnCode" != 0 ] && echo " WARN  Action \"$action\" returned with code $returnCode" >&2
		exit "$returnCode"
	else
		echo "ERROR  Unknown action \"$action\", see usage" >&2
		usage
		exit 1
	fi
fi


# Install signal/exit handlers
# ----------------------------------------------------------------------

trap handleExit EXIT
trap handleSignalReloadConfig USR1
trap stop TERM INT QUIT HUP


# Enter the main loop
# ----------------------------------------------------------------------

while ! $stopped; do
	$verbose && echo "DEBUG  ---- Start of main loop iteration ----" >&2
	isReloadRequired && reloadConfig

	runActionTestAndTrigger

	sleep "$pollingInterval" & sleepPid=$!
	wait $sleepPid || true
	sleepPid=""
done
