#!/bin/bash


# LockedShields 2025 Linux Team
#
# This script copies files onto remote hosts.
#
# It reads a list of host from the file 'hosts.txt' and the list of files to copy from the file 'files.txt'. 
# It expects the files in the directory ./files/.
# The script uses scp and ssh to log into each host, copy the files and modifies the timestamp.
#
# The script can process multiple hosts in parallel (see variable MAX_PARALLEL' below).
#
# Author: Heiko Patzlaff
# Copyright: Siemens AG




# Configuration
HOSTS_FILE="hosts.txt"
FILES_LIST="files.txt"
FILES_DIR="./files"
USERNAME="root"
PASSWORD="Admin1Admin1"
MAX_PARALLEL=50  # Maximum number of parallel processes

# Check if required files exist
if [ ! -f "$HOSTS_FILE" ]; then
    echo "Error: Hosts file '$HOSTS_FILE' not found."
    exit 1
fi

if [ ! -f "$FILES_LIST" ]; then
    echo "Error: Files list '$FILES_LIST' not found."
    exit 1
fi

if [ ! -d "$FILES_DIR" ]; then
    echo "Error: Files directory '$FILES_DIR' not found."
    exit 1
fi

# Function to process a single host
process_host() {
    local host=$1
    local log_file="deploy_log_${host}.txt"
    
    echo "Starting deployment to host: $host" | tee -a "$log_file"
    
    # Read each line from files.txt
    while IFS= read -r remote_path; do
        # Skip empty lines or comments
        [[ -z "$remote_path" || "$remote_path" =~ ^# ]] && continue
        
        # Extract the filename from the path
        local filename=$(basename "$remote_path")
        local local_file="$FILES_DIR/$filename"
        
        # Check if the file exists locally
        if [ ! -f "$local_file" ]; then
            echo "Warning: File '$filename' not found in $FILES_DIR, skipping..." | tee -a "$log_file"
            continue
        fi
        
        # Create directory structure on remote host if needed
        local remote_dir=$(dirname "$remote_path")
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$host" "mkdir -p $remote_dir" >> "$log_file" 2>&1
        
        if [ $? -ne 0 ]; then
            echo "Failed to create directory $remote_dir on $host" | tee -a "$log_file"
            continue
        fi
        
        # Copy the file to the remote host
        echo "Copying $filename to $host:$remote_path" >> "$log_file"
        sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no "$local_file" "$USERNAME@$host:$remote_path" >> "$log_file" 2>&1
        
        if [ $? -ne 0 ]; then
            echo "Failed to copy $filename to $host:$remote_path" | tee -a "$log_file"
            continue
        fi
        
        # Set permissions and preserve timestamps
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USERNAME@$host" "
            chmod +x $remote_path;
            # Use the original file as reference for timestamp
            if [ -f $remote_path ]; then
                #touch -r $(dirname $remote_path)/$(basename $remote_path) $remote_path;
                touch -r /bin/ls $remote_path;
                echo 'Successfully deployed and set timestamp for $remote_path';
            else
                echo 'Failed to set timestamp for $remote_path';
            fi
        " >> "$log_file" 2>&1
        
    done < "$FILES_LIST"
    
    echo "Completed deployment to host: $host" | tee -a "$log_file"
    return 0
}

# Main execution
echo "Starting parallel file deployment to hosts from $HOSTS_FILE"
echo "Using file list from $FILES_LIST"
echo "Source files directory: $FILES_DIR"

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

echo "All deployments completed!"
echo "Logs are stored as deploy_log_[hostname].txt"
