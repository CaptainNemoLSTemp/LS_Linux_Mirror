#!/bin/bash

# LockedShields 2025 Linux Team
#
# This script runs a command on remote hosts (see variable CMD below).
#
# It reads a list of host from the file 'hosts.txt'.
#
# The script can process multiple hosts in parallel (see variable MAX_PARALLEL' below).
#
# Author: Heiko Patzlaff
# Copyright: Siemens AG



# Configuration
HOSTS_FILE="hosts.txt"
USERNAME="root"
PASSWORD="Admin1Admin1"
REMOTE_TMP="/tmp"
MAX_PARALLEL=100  # Maximum number of parallel processes
CMD="chattr -i /etc/passwd && chattr -i /etc/sudoers"

# Function to process a single host
process_host() {
    local host=$1
    local log_file="log_${host}.txt"
    
    echo "Starting process for host: $host"
    
    # Clean up remote system
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$host" "$CMD" >> "$log_file" 2>&1
    
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


