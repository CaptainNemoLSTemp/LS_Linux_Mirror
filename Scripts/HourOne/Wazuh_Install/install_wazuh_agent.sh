#!/bin/bash

# Define the path to the Wazuh .deb file and the path where it will be copied on the remote machine
LOCAL_DEB_FILE="wazuh-agent_4.11.1-1_amd64.deb"
REMOTE_PATH="/root/tmp/wazuh-agent_4.11.1-1_amd64.deb"
WAZUH_MANAGER_IP="100.101.202.10"  # The Wazuh manager IP
REMOTE_DIR="/root/tmp"

# Path to your hosts.txt file
HOSTS_FILE="hosts.txt"

# The SSH private key file for authentication
SSH_KEY="/root/.ssh/skeletonkey"

# Function to copy and install Wazuh agent
install_wazuh_agent() {
    local username=$1
    local ip=$2
    local remote_dir=$(dirname "$REMOTE_PATH")

    echo "Processing $username@$ip..."

    # Create the parent directory on the remote machine using SSH
    echo "Creating remote directory $REMOTE_DIR"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$username@$ip" "mkdir -p $REMOTE_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create remote directory $REMOTE_DIR on $username@$ip."
        return 1
    fi

    # Copy the Wazuh agent .deb file to the remote machine using SCP with StrictHostKeyChecking=no
    echo "Copying $LOCAL_DEB_FILE to $username@$ip:$REMOTE_PATH"
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$LOCAL_DEB_FILE" "$username@$ip:$REMOTE_PATH"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy the Wazuh agent to $username@$ip."
        return 1
    fi
    
    # Run the installation command on the remote machine
    echo "Running installation command on $username@$ip"
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$username@$ip" "WAZUH_MANAGER='$WAZUH_MANAGER_IP' dpkg -i $REMOTE_PATH"
    if [ $? -ne 0 ]; then
        echo "Error: Installation of Wazuh agent failed on $username@$ip."
        return 1
    fi

    echo "Starting Wazuh agent service on $username@$ip"
    
    # Start the Wazuh agent service in the background using nohup
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$username@$ip" "nohup systemctl daemon-reload && nohup systemctl enable wazuh-agent && nohup systemctl start wazuh-agent > /dev/null 2>&1 &"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to start the Wazuh agent service on $username@$ip."
        return 1
    fi

    echo "Wazuh agent installed and started successfully on $username@$ip"
}

# Read the hosts.txt file line by line
while IFS=':' read -r username password ip; do
    # Skip empty lines and lines starting with a comment (#)
    if [[ -z "$username" || -z "$ip" || "$username" == \#* ]]; then
        continue
    fi

    # Call the function to copy and install the Wazuh agent in the background
    install_wazuh_agent "$username" "$ip" &
done < "$HOSTS_FILE"

# Wait for all background processes to complete
wait

echo "Script completed."