#!/bin/bash
set -o nounset
set -o noclobber
set -o errexit
shopt -qs inherit_errexit

declare -r VERSION=0.0.1-dev

# Prints the version string to STDOUT
getVersion () {
	echo -n "${VERSION}"
}

# isFunction command
#
# Returns with code 0 if the given command refers to a function
# (and not, for example, to a shell builtin or an executable)
isFunction () {
	local command="$1"; shift
	local commandType

	! commandType="$(type -t "$command")" && return 1
	! test "function" = "$commandType" && return 1
	return 0
}

# Returns the paths to all existing valid system-level configuration
# files, in ascending order of priority
#
# The paths are returned in a newline-separated list
getConfigurationFilesSystem () {
	getConfigurationFiles "/usr/lib" "/etc" "/run"
}

# Returns the paths to all existing valid user-level configuration
# files, in ascending order of priority
#
# The paths are returned in a newline-separated list
getConfigurationFilesUser () {
	getConfigurationFiles ~/".config"
}

# getConfigurationFiles baseDir [otherBaseDir...]
#
# Returns the paths to all existing valid configuration files, in
# ascending order of priority, in the given directories
#
# The paths are returned in a newline-separated list
# The directories must be given without trailing slash
getConfigurationFiles () {
	local suffix=".conf"
	local pathPrefix
	local configDir
	local configFile
	local baseDir

	while test $# -gt 0; do
		baseDir="$1"; shift
		pathPrefix="${baseDir}/meeting-trigger/meeting-trigger"
		configDir="${pathPrefix}.d"
		configFile="${pathPrefix}$suffix"

		if test -d "$configDir"; then
			find "$configDir" -mindepth 1 -maxdepth 1 -type f -name "*$suffix" -print | sort
		fi
		if test -f "$configFile"; then
			echo "$configFile"
		fi
	done
}

# Prints an initial configuration file to STDOUT
printTemplateConfigurationFile () {

	echo '# Configuration file for meeting-trigger
# ======================================================================

# Created by meeting-trigger '$(getVersion)' 

# Application names to ignore:
ignoreList=()
#ignoreList+=("qemu-system-x86_64") #example of adding an application to the ignore list

# Directory that holds scripts that will be called when the mic changes state (or following the forced trigger rules below)
triggerDir="${HOME}/.config/meeting-trigger/scripts"

# Sets whether to call triggers when monitoring first starts
# Valid options are: on-only; off-only; both; none
# Default is "both", which always makes an initial call setting "the external state"
triggerInitialState="on-only"

# How long the main loop should sleep before polling again
pollingInterval="5s"

# Polls count that the system must trigger (on or off) even if the mic state does not change
# Default is 0, which disables this forced triggering. Use "1" to force a trigger for every poll;
# Example, to force a trigger every 15min use: 15*60s/pollingInterval (say 5s) = 180
forceTriggerInterval=0

# Sets the forced trigger type (from above interval)
# Valid options are: on-only; off-only; both
forceTriggerType="both"

# Whether to print DEBUG messages to STDERR
verbose=false'
}

# Prints sample action script to STDOUT
printSampleScript () {
	echo '#!/bin/bash

# Sample meeting-trigger script action
# $1 = [on|off]
# Feel free to delete or change this for your own use

if [ "$1" = "on" ]; then
        #trigger something when mic is on
        echo "Mic is in use"

else #assuming off
  #... and something else when it is no longer in use
        echo "Mic is NOT in use"

fi'
}

# Prints sample ifttt.com script to STDOUT
printSampleIfttt () {
	echo '#!/bin/bash

# Sample Meeting-trigger ifttt.com webhook action call

# Create your applets with a webhook trigger
# And setup your markers events name ending with an "on" or "off" suffix
# Example:
# Create an webhook-triggered applet (no json) for the marker event: lights_on
# Then another applet for the marker event: lights_off
event_basename="lights_"

# Then open: https://ifttt.com/maker_webhooks
# Click on the "Documentation" link, which should show your private webhook key
webhook_key="put your key here"

# Delete or comment the following line to "enable" this script action
exit 0

# Actual webhook call. Concatenating the event_basename with the on/off parameter this script receives from the daemon
curl -s "https://maker.ifttt.com/trigger/${event_basename}$1/with/key/${webhook_key}" && echo'
}

# Sources all existing configuration files, also re-populates the
# $configFilesMonitored associative array
loadSettingsFromConfigFiles () {
	local -i exitCode
	local configFile

	reloadConfig=false

	# Source the system-level configuration files
	while read -rs configFile; do
		echo " INFO  Sourcing configuration file \"$configFile\"" >&2
		# shellcheck source=/dev/null
		source -- "$configFile" && exitCode=$? || exitCode=$?
		if test "$exitCode" -ne 0; then
			echo "ERROR  Could not source configuration file \"$configFile\"" >&2
			exit "$exitCode"
		fi
	done < <(getConfigurationFilesSystem)

	# Source the user-level configuration files (these are monitored for changes)
	# Set all entries in the "monitored configuration files" map to "File not found"
	for configFile in "${!configFilesMonitored[@]}"; do
		configFilesMonitored["$configFile"]=""
	done
	while read -rs configFile; do
		echo " INFO  Sourcing configuration file \"$configFile\"" >&2
		# shellcheck source=/dev/null
		source -- "$configFile" && exitCode=$? || exitCode=$?
		if test "$exitCode" -ne 0; then
			echo "ERROR  Could not source configuration file \"$configFile\"" >&2
			exit "$exitCode"
		fi
		configFilesMonitored["$configFile"]="$(getFileStatus "$configFile")"
	done < <(getConfigurationFilesUser)
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
	if ! test "$verbose" = true && ! test "$verbose" = false; then
		echo " WARN  \$verbose must be either \"true\" or \"false\", was \"$verbose\", using \"false\" instead" >&2
		verbose=false
	fi

	# TODO code this
}

# (Re)loads the configuration and validates the resulting settings
reloadConfig() {
	reloadConfig=false
	setDefaultSettings
	loadSettingsFromConfigFiles
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


# Special actions
# ----------------------------------------------------------------------

# runActionEditConfig [customEditor] [customEditorArgument]...
#
# Opens the primary configuration file in a text editor
# Creates a new configuration file if it does not exist yet
runActionEditConfig () {
	local configFile=~/.config/meeting-trigger/meeting-trigger.conf
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
	if ! test -e "$configFile"; then
		echo " INFO  Configuration file does not exist, creating it" >&2
		# Create the configuration file's parent directories if they do not exist
		mkdir --parents "$(dirname "$configFile")/scripts"
		printTemplateConfigurationFile > "$configFile"
		# Create scripts dir
		mkdir --parents "$triggerDir"
		printSampleScript > "${triggerDir}/sample.sh"
		printSampleIfttt > "${triggerDir}/ifttt.sh"
		chmod u=rwx,go=rx "${triggerDir}"/{sample,ifttt}.sh
	fi

	# Launch the text editor with the arguments and the configuration file's path
	echo " INFO  Editing configuration file with \"$editor\": \"$configFile\"" >&2
	$verbose && echo "DEBUG  Launching text editor: \"$editor\" $* \"$configFile\"" >&2
	"$editor" "$@" "$configFile"
}

# runActionTrigger on/off
runActionTrigger () {
	local verboseParam=""
	if $verbose; then
		echo "DEBUG  running triggers $1" >&2
		verboseParam="-v"
	fi
	run-parts $verboseParam --regex='.' -a "$1" -- "$triggerDir" >&2
	forcedIntervalCounter=0
}

# Prints "on" if any (non-ignored) app is reading the mic, "off" otherwise
runActionDetectMicState() {
	$verbose && echo "DEBUG  detecting mic state" >&2
	while read -rs app; do
		if ! [[ ${ignoreList[*]} =~ (^|[[:space:]])"$app"($|[[:space:]]) ]]; then
			echo -n "on"
		return
	fi
	done < <( pacmd list-source-outputs|grep 'application.name ='|cut -d'"' -f2 )
	echo -n "off"
}

# Detects if state change and trigger actions accordingly
runActionTestAndTrigger () {
	$verbose && echo "DEBUG  running test and trigger" >&2
	local newState="$(runActionDetectMicState)"
	$verbose && echo "currentState=$currentState; newState=$newState" >&2
	if [ "$newState" != "$currentState" ]; then
		currentState="$newState"
		runActionTrigger "$currentState"
	elif [ $forceTriggerInterval -gt 0 ]; then
		((forcedIntervalCounter++)) || true
		if [ $forcedIntervalCounter -ge $forceTriggerInterval ]; then
			if [ "$forceTriggerType" = "both" ] ||
		  		[ "$forceTriggerType" = "on-only" -a "$currentState" = "on" ] ||
				 "$forceTriggerType" = "off-only" -a "$currentState" = "off" ]; then

				$verbose && echo "forcing trigger count $forcedIntervalCounter" >&2
				runActionTrigger "$currentState"
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

# The user-level configuration files that are currently effective
# Used to check whether they have been modified
# Key is the file path, value is file size and modification time,
# separated by a space
declare -A configFilesMonitored
# Pre-load the map with the primary user-level configuration file, so
# that it will be picked up if it is created during runtime
configFilesMonitored[~/".config/meeting-trigger.conf"]=""

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


# Handler for special single argument "--help"
# ----------------------------------------------------------------------

if test $# -eq 1 && test "$1" = "--help"; then
	echo -n "meeting-trigger "; getVersion
	echo -n \
'Meeting-trigger daemon

Usage:
  meeting-trigger
  meeting-trigger --help
  meeting-trigger --version
  meeting-trigger EditConfig [customEditor] [customEditorArgument]...
  meeting-trigger DetectMicState
  meeting-trigger Trigger [on|off]
  meeting-trigger TestAndTrigger

Monitors a running PulseAudio server instance and checks for applications reading the mic

When a change in state is detected (meeting "started" or "ended") then the appropriate triggers are called
'
	exit 0
fi


# Handler for special single argument "--version"
# ----------------------------------------------------------------------

if test $# -eq 1 && test "$1" = "--version"; then
	getVersion
	exit 0
fi


# Apply/load and validate the settings
# ----------------------------------------------------------------------

reloadConfig
# set initial currentState depending on config to trigger (or not) initially
if test "$triggerInitialState" = "none"; then
  currentState="$(runActionDetectMicState)"
elif test "$triggerInitialState" = "on-only"; then
  currentState="off"
elif test "$triggerInitialState" = "off-only"; then
  currentState="on"
else #assuming "both"
  currentState="initial"
fi

# Print an overview
# ----------------------------------------------------------------------

echo -n " INFO  This is meeting-trigger " >&2; getVersion >&2
$verbose && echo "DEBUG  Verbose output is enabled" >&2


# Handle special action if present
# ----------------------------------------------------------------------

# Run a special action instead of the regular daemon if such an action
# is given as first argument
if test $# -gt 0; then
	action="$1"; shift
	actionFunction="runAction$action"

	if isFunction "$actionFunction"; then
		$verbose && echo "DEBUG  Running action \"$action\" with $# argument(s)" >&2
		"$actionFunction" "$@" && actionFunctionReturnCode="$?" || actionFunctionReturnCode="$?"
		if test "$actionFunctionReturnCode" != 0 ; then
			echo " WARN  Action \"$action\" returned with code $actionFunctionReturnCode" >&2
		fi
		exit "$actionFunctionReturnCode"
	else
		echo -n "ERROR  Unknown action \"$action\", must be one of:" >&2
		# Print all available actions
		while read -rs validAction; do
			echo -n " \"$validAction\"" >&2
		done < <(declare -F | sed -nre 's/^declare -f //;s/^runAction(.+)$/\1/p')
		echo >&2
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

	if isReloadRequired; then
		reloadConfig
	fi
	runActionTestAndTrigger

	if ! sleep "$pollingInterval" & sleepPid=$!; then
		sleep "5s" & sleepPid=$!
	fi
	wait $sleepPid || true
	sleepPid=""
done
