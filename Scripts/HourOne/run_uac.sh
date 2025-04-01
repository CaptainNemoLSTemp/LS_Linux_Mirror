#!/bin/bash

# LockedShields 2025 Linux Team
#
# This script runs the Unix-like Artifacts Collector (uac) on remote hosts and collects the results.
# see https://github.com/tclahr/uac
# 
# It reads a list of host from the file 'hosts.txt'. It uses scp and ssh to log into each host,
# copy the uac archive 'uac.tgz' onto the remote host, executes the enclosed uac shell script,
# transfers the generated archive file 'uac-*.tar.gz' back and finally cleans up any temporary files.
# 
# The script can process multiple hosts in parallel (see variable MAX_PARALLEL' below).
#
# Author: Heiko Patzlaff
# Copyright: Siemens AG


# Configuration
HOSTS_FILE="hosts.txt"
USERNAME="root"
PASSWORD="Admin1Admin1"
ARCHIVE="uac.tgz"
REMOTE_TMP="/tmp"
MAX_PARALLEL=100  # Maximum number of parallel processes

# Function to process a single host
process_host() {
    local host=$1
    local log_file="log_${host}.txt"
    
    echo "Starting process for host: $host"
    
    # Copy archive to remote system
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no "$ARCHIVE" "$USERNAME@$host:$REMOTE_TMP/" > "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to copy archive to $host"
        return 1
    fi
    echo "copyied archive to: $host"
    
    # Unpack archive and run script
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$host" "
        cd $REMOTE_TMP && 
        tar -xzf $ARCHIVE && 
        cd uac-3.1.0 && 
        ./uac -p lockedshields $REMOTE_TMP
    " >> "$log_file" 2>&1
    
    if [ $? -ne 0 ]; then
        echo "Failed to run script on $host"
        return 1
    fi
    
    # Copy results back
    sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no "$USERNAME@$host:$REMOTE_TMP/uac-*.tar.gz" "." >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "Failed to copy results from $host"
        return 1
    fi
    
    # Clean up remote system
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$host" "
        rm -rf $REMOTE_TMP/$ARCHIVE $REMOTE_TMP/uac* $REMOTE_TMP/mylog.log && 
        history -c
    " >> "$log_file" 2>&1
    
    echo "Completed process for host: $host"
    return 0
}

# Main execution
echo "Starting parallel execution on hosts from $HOSTS_FILE"

# Read hosts and process them in parallel
cat "$HOSTS_FILE" | while read host; do
    # Skip empty lines or comments
    [[ -z "$host" || "$host" =~ ^# ]] && continue
    
    # Check number of running processes and wait if needed
    while [ $(jobs -p | wc -l) -ge $MAX_PARALLEL ]; do
        sleep 1
    done
    
    # Process host in background
    process_host "$host" &
    
    # Small delay to prevent overwhelming the system
    sleep 0.2
done

# Wait for all background processes to complete
wait

echo "All processes completed!"
echo "Logs are stored as log_[hostname].txt"


