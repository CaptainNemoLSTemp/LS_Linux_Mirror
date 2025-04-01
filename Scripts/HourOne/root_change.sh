#!/bin/bash

HOSTS_FILE="hosts.txt"
SSH_KEY="/root/.ssh/testkey.pub"
OUTPUT_FILE="passwords.txt"

> "$OUTPUT_FILE"

while IFS=: read -r username password ip; do
    NEW_PASSWORD=$(openssl rand -base64 20)  
    echo "New password for $ip: $NEW_PASSWORD"

    sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$ip" << EOF
        echo "root:$NEW_PASSWORD" | sudo chpasswd
        echo "Password for root on $ip has been changed successfully."
EOF

    echo "root:$NEW_PASSWORD:$ip" >> "$OUTPUT_FILE"

    echo "Copying the SSH public key to root@$ip..."
    sshpass -p "$NEW_PASSWORD" ssh-copy-id -i "$SSH_KEY" -o StrictHostKeyChecking=no "$username@$ip"

done < "$HOSTS_FILE"

echo "All new passwords have been written to $OUTPUT_FILE"