#!/bin/bash

# Path to your SSH key (make sure it's secured)
SSH_KEY="~/.ssh/id_rsa"

# Name of the new user
NEW_USER="newuser"
USER_GROUP="newgroup"  # The group the user should be added to

# Check if input file (hosts list) exists
HOSTS_FILE="hosts.txt"
if [[ ! -f "$HOSTS_FILE" ]]; then
    echo "Hosts file not found!"
    exit 1
fi

# Loop through the file, where each line is in the format username:password:hostIP
while IFS=":" read -r username password hostIP; do
    echo "Processing $hostIP..."
    
    # Use Expect to handle SSH login and user creation
    /usr/bin/expect <<EOF
    spawn ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$username@$hostIP"
    expect {
        "*password:" { send "$password\r"; exp_continue }
        "*$ " { send "sudo adduser $NEW_USER --disabled-password --gecos \"\" && sudo usermod -aG $USER_GROUP $NEW_USER && echo \"User $NEW_USER created and configured successfully\" && exit\r" }
    }
    expect eof
EOF

    # Check if the user was created and configured successfully
    if [[ $? -eq 0 ]]; then
        echo "User $NEW_USER created successfully on $hostIP."
    else
        echo "Failed to create user $NEW_USER on $hostIP."
    fi
done < "$HOSTS_FILE"
