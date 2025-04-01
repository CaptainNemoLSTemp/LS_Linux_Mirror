#!/bin/bash

# Path to your SSH key file
SSH_KEY="/root/.ssh/DMZ1.pub"

# Path to your file containing user:password:IPaddress format
USER_FILE="users.txt"

# Loop through each line in the file
while IFS=":" read -r username password ip; do
    # Check if all three fields are provided (username, password, IP)
    if [[ -n "$username" && -n "$password" && -n "$ip" ]]; then
        echo "Copying SSH key to $username@$ip..."
        
        # Use sshpass to copy the SSH key
        sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no -i "$SSH_KEY" "$username@$ip"
        
        if [ $? -eq 0 ]; then
            echo "SSH key copied successfully to $username@$ip"
        else
            echo "Failed to copy SSH key to $username@$ip"
        fi
    else
        echo "Invalid entry in users file. Skipping line: $username:$password:$ip"
    fi
done < "$USER_FILE"
