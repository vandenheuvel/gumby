#!/bin/bash
# isolated_tribler_network.sh ---
#
# Filename: isolated_tribler_network.sh
# Description:
# Author: Elric Milon
# Maintainer:
# Created: Tue Jan  6 17:58:59 2015 (+0100)

# Commentary:
#
#
#
#

# Change Log:
#
#
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
#
#

# Code:

# @CONF_OPTION ISOLATED_CMD: Command to be executed and waited for on the isolated dispersy network (no default)
# @CONF_OPTION ISOLATED_INSTANCES_TO_SPAWN: Amount of copies of ISOLATED_INSTANCES_CMD to spawn.
# @CONF_OPTION ISOLATED_INSTANCES_CMD: Command to be executed repeatedly, if ISOLATED_CMD these are the processes we
# will wait for before finishing (no default)

# Start a dedicated tracker (isolated from the network)
TRACKER_IP=127.0.0.1 HEAD_HOST=localhost run_tracker.sh &
TRACKER_PID=$!

# Make sure the tracker didn't fail to start
sleep 2
if [ ! -e /proc/$TRACKER_PID ]; then
    echo "The tracker didn't start correctly, bailing out."
    exit 1
fi

# Start N instances of Tribler that will only contact the isolated tracker.
if [ -z "$ISOLATED_INSTANCES_TO_SPAWN" ]; then
    echo 'ISOLATED_INSTANCES_TO_SPAWN not defined, bailing out.'
    exit 2
fi

MINIONS=$ISOLATED_INSTANCES_TO_SPAWN

mkdir -p $HOME/tmp/

TMP_PREFIX=$(mktemp -d -p $HOME/tmp/)
COMMANDS_FILE=$(mktemp -p $TMP_PREFIX)

export TRIBLER_ALLOW_MULTIPLE=True
export TMPDIR=$TMP_PREFIX
export TRIBLER_SKIP_OPTIN_DLG=True
export DISPERSY_BOOTSTRAP_FILE="$PWD/tribler/bootstraptribler.txt"

while [ $MINIONS -gt 0 ]; do
    echo $ISOLATED_INSTANCES_CMD >> $COMMANDS_FILE
    let MINIONS=$MINIONS-1
done

process_guard.py -m $OUTPUT_DIR/isolated_instances -o $OUTPUT_DIR/isolated_instances  -f $COMMANDS_FILE &
PROCESS_GUARD_PID=$!



let SLEEP_TIME=$ISOLATED_INSTANCES_TO_SPAWN*3
echo "Waiting for $SLEEP_TIME secs. to make sure the Tribler instances are running..."
sleep $SLEEP_TIME
echo "Going forth"

# Make sure nothing is wrong and process_guard.py hasn't exited already
if [ ! -e /proc/$PROCESS_GUARD_PID ]; then
    echo "The Tribler instances didn't start correctly, bailing out."
    exit 3
fi

# Call the callback executable.
if [ -z "$ISOLATED_CMD" ]; then
    echo "Waiting for the isolated instances to finish"
    wait $PROCESS_GUARD_PID
else
    echo "Unsetting HOME_SEED_FILE"
    unset HOME_SEED_FILE
    echo "Executing isolated cmd"
    $ISOLATED_CMD
fi

# if this is empty wait for PROCESS_GUARD_PID

# Clean up the mess.
killing_it_softly () {
    PID=$1
    kill $PID
    sleep 0.1
    if [ -e /proc/$PID ]; then
        sleep 2
        if [ -e /proc/$PID ]; then
            kill -3 $PID
            sleep 1
            if [ -e /proc/$PID ]; then
                kill -9 $PID
            fi
        fi
    fi
}

killing_it_softly $TRACKER_PID
killing_it_softly $PROCESS_GUARD_PID

rm -fR $TMP_PREFIX

#
# isolated_tribler_network.sh ends here
