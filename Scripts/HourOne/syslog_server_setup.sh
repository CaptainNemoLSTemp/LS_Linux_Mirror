#!/bin/bash
# Enable strict error handling
set -euo pipefail

# Define variables
RSYSLOG_CONF="/etc/rsyslog.conf"
BACKUP_CONF="/etc/rsyslog.conf.bak"
ERROR_LOG="/var/log/syslog"
UDP_PORT="514"
TMP_CONF="/tmp/rsyslog_temp_conf_$$"

# Clean up temp file on exit
trap 'rm -f "$TMP_CONF"' EXIT

# Function to print logs if Rsyslog fails
print_error_logs() {
    echo "ERROR: Rsyslog failed to start. Printing last 20 error log lines:"
    sudo journalctl -u rsyslog --no-pager --since "10 minutes ago" | tail -20 || echo "Could not retrieve logs from journalctl"
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for rsyslog binary
echo "Checking for rsyslog installation..."
if command_exists rsyslogd; then
    echo "Rsyslog is installed."
else
    echo "WARNING: rsyslogd command not found."
    
    # Look for binary in common locations
    for path in /usr/sbin/rsyslogd /sbin/rsyslogd; do
        if [ -x "$path" ]; then
            echo "Found rsyslog binary at $path."
            export PATH="$PATH:$(dirname "$path")"
            break
        fi
    done
    
    # If still not found, attempt installation
    if ! command_exists rsyslogd; then
        echo "Attempting to install rsyslog..."
        # Try local package installation first (for no internet scenarios)
        if ls /var/cache/apt/archives/rsyslog*.deb >/dev/null 2>&1; then
            echo "Found local rsyslog package, attempting installation..."
            sudo dpkg -i /var/cache/apt/archives/rsyslog*.deb && echo "Successfully installed from local package."
        else
            echo "ERROR: Could not find or install rsyslog."
            echo "Suggestions:"
            echo " - Try manual repair: sudo dpkg --configure -a"
            echo " - Copy rsyslog binary from another system"
            echo " - Install from package: sudo dpkg -i rsyslog_*.deb"
            exit 1
        fi
    fi
fi

# Backup the original rsyslog.conf if not already backed up
if [ ! -f "$BACKUP_CONF" ]; then
    echo "Creating backup of rsyslog configuration..."
    sudo cp "$RSYSLOG_CONF" "$BACKUP_CONF" || {
        echo "ERROR: Failed to create backup of $RSYSLOG_CONF"
        exit 1
    }
    echo "Backup created: $BACKUP_CONF"
else
    echo "Backup already exists."
fi

# Add UDP syslog reception if not already configured
if ! grep -q "imudp" "$RSYSLOG_CONF"; then
    echo "Configuring UDP syslog reception on port $UDP_PORT..."
    
    # Create a temporary file for new configuration
    sudo cp "$RSYSLOG_CONF" "$TMP_CONF"
    
    # Append new configuration
    sudo bash -c "cat >> $TMP_CONF" <<EOL

# Provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="$UDP_PORT")

# Define remote log storage format
\$template RemoteLogs,"/var/log/%HOSTNAME%/%PROGRAMNAME%.log"
*.* ?RemoteLogs
& ~
EOL

    # Test the configuration before applying
    if sudo rsyslogd -f "$TMP_CONF" -N1 >/dev/null 2>&1; then
        sudo cp "$TMP_CONF" "$RSYSLOG_CONF" || {
            echo "ERROR: Failed to update $RSYSLOG_CONF"
            exit 1
        }
        echo "UDP syslog reception configured on port $UDP_PORT"
    else
        echo "ERROR: Invalid configuration. Not updating $RSYSLOG_CONF"
        exit 1
    fi
else
    echo "UDP syslog reception is already configured."
fi

# Create required log directories
echo "Creating log directories..."
sudo mkdir -p /var/log
sudo chmod 755 /var/log

# Restart rsyslog to apply changes
echo "Restarting Rsyslog service..."

# Try multiple restart methods for maximum compatibility
if command_exists systemctl; then
    if sudo systemctl restart rsyslog.service; then
        echo "Rsyslog restarted successfully via systemctl."
    else
        echo "WARNING: Failed to restart via systemctl, trying alternative methods..."
        if sudo service rsyslog restart 2>/dev/null; then
            echo "Rsyslog restarted successfully via service command."
        else
            rsyslogd_pid=$(pgrep rsyslogd 2>/dev/null)
            if [ -n "$rsyslogd_pid" ] && sudo kill -HUP "$rsyslogd_pid"; then
                echo "Sent HUP signal to rsyslog process."
            else
                print_error_logs
            fi
        fi
    fi
else
    if sudo service rsyslog restart 2>/dev/null; then
        echo "Rsyslog restarted successfully via service command."
    else
        print_error_logs
    fi
fi

# Check if Rsyslog restarted successfully
if command_exists systemctl && sudo systemctl is-active --quiet rsyslog; then
    echo "Verified: Rsyslog service is active."
elif pgrep rsyslogd >/dev/null 2>&1; then
    echo "Verified: Rsyslog process is running."
else
    print_error_logs
fi

# Open firewall for UDP port (if using UFW)
if command_exists ufw; then
    echo "Allowing UDP $UDP_PORT through UFW firewall..."
    sudo ufw allow "$UDP_PORT"/udp && sudo ufw reload
    echo "Firewall rule added."
# Check for iptables as an alternative
elif command_exists iptables; then
    echo "Allowing UDP $UDP_PORT through iptables..."
    sudo iptables -C INPUT -p udp --dport "$UDP_PORT" -j ACCEPT 2>/dev/null || 
    sudo iptables -A INPUT -p udp --dport "$UDP_PORT" -j ACCEPT
    echo "Iptables rule added (note: may not persist after reboot)."
else
    echo "WARNING: No recognized firewall found. Please manually ensure UDP port $UDP_PORT is open."
fi

echo "Rsyslog setup completed successfully."
echo "Remote logs will be stored in /var/log/<hostname>/<program>.log"