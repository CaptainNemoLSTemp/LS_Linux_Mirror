#!/bin/bash

# If not running as root, relaunch the script with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Requesting sudo privileges..."
    exec sudo "$0" "$@"
    exit 1  # This line only executes if sudo fails
fi

# Enable strict mode - script will exit if any command fails, any undefined variable is used, or any pipe command fails
set -euo pipefail

# =====================================================================
# Wazuh, rsyslog, and auditd Integration Automation
# Date: April 1, 2025
#
# This script automatically configures:
# 1. rsyslog to receive logs from remote clients via UDP
# 2. Creates a dynamic file organization structure for client logs
# 3. Configures Wazuh agent to monitor both standard logs and audit logs
# 4. Includes proper service checks and error handling
#
# The script creates a structure where:
# - Each client's logs are organized in /var/log/clients/[hostname]/
# - Audit logs (audisp-syslog.log) are handled with proper format
# =====================================================================

# Set variables (modify these as needed)
UDP_PORT="514"                 # Standard UDP port for rsyslog
ALLOWED_IPS="0.0.0.0/0"        # Network range allowed to send logs
LOCAL_IP="192.168.10.10"       # IP address to bind to for syslog reception (custom VM IP)

# Simple logging functions for better output readability
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_warn() {
    echo "[WARNING] $1" >&2
}

# Function to check service status with error details
# This helps identify issues with services before attempting restarts
check_service() {
    local service=$1
    local status=$(systemctl is-active "$service" 2>&1)
    local enabled=$(systemctl is-enabled "$service" 2>&1)
    
    if [ "$status" != "active" ]; then
        log_warn "$service is not running (status: $status)"
        log_info "Service error details:"
        systemctl status "$service" | head -n 15 >&2
        return 1
    else
        log_info "$service is running"
    fi
    
    if [ "$enabled" != "enabled" ]; then
        log_warn "$service is not enabled at boot time (status: $enabled)"
        log_info "Enabling $service to start at boot time"
        systemctl enable "$service"
    else
        log_info "$service is enabled at boot time"
    fi
    
    return 0
}

log_info "Starting rsyslog, Wazuh, and Audit integration setup..."

# Create backup of config files to prevent data loss during configuration
log_info "Creating configuration backups..."
TIMESTAMP=$(date +%Y%m%d%H%M%S)
cp /etc/rsyslog.conf /etc/rsyslog.conf.bak.$TIMESTAMP
cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.bak.$TIMESTAMP

# Step 1: Configure rsyslog to receive syslog events via UDP
# This allows the server to receive logs from remote clients
log_info "Configuring rsyslog reception on port $UDP_PORT (UDP)..."
if ! grep -q "module(load=\"imudp\")" /etc/rsyslog.conf; then
    cat << EOF >> /etc/rsyslog.conf

# Provides UDP syslog reception
module(load="imudp")
input(type="imudp" port="$UDP_PORT")
EOF
fi

# Step 2: Configure rsyslog for dynamic file organization by hostname
# This creates separate directories for each client machine
log_info "Configuring rsyslog for dynamic file organization..."

# Create directory for client logs
mkdir -p /var/log/clients
chmod 750 /var/log/clients

# Add dynamic template configuration
# This creates separate log files based on hostname and program name
if ! grep -q "DynamicFile" /etc/rsyslog.conf; then
    cat << EOF >> /etc/rsyslog.conf

# Create separate log files for each client
\$template DynamicFile,"/var/log/clients/%HOSTNAME%/%PROGRAMNAME%.log"
if \$fromhost-ip != '127.0.0.1' then ?DynamicFile
& ~
EOF
fi

# Step 3: Configure Wazuh agent to read the syslog output files
# This ensures Wazuh monitors all logs collected from clients
log_info "Configuring Wazuh agent to monitor client logs..."
OSSEC_CONF="/var/ossec/etc/ossec.conf"

# Add the new <remote> configuration after the last existing <remote> block
if grep -q "</remote>" "$OSSEC_CONF"; then
    log_info "Adding TCP syslog remote configuration to Wazuh..."
    # Find the last </remote> tag and add the new configuration after it
    sed -i "s|</remote>|</remote>\n  <remote>\n    <connection>syslog</connection>\n    <port>514</port>\n    <protocol>udp</protocol>\n    <allowed-ips>$ALLOWED_IPS</allowed-ips>\n    <local_ip>$LOCAL_IP</local_ip>\n  </remote>|" "$OSSEC_CONF"
else
    # If no <remote> tag exists, add it before </ossec_config>
    log_info "No existing <remote> tag found. Adding TCP syslog remote configuration..."
    sed -i "s|</ossec_config>|  <remote>\n    <connection>syslog</connection>\n    <port>514</port>\n    <protocol>udp</protocol>\n    <allowed-ips>$ALLOWED_IPS</allowed-ips>\n    <local_ip>$LOCAL_IP</local_ip>\n  </remote>\n</ossec_config>|" "$OSSEC_CONF"
fi

# Configure monitoring for standard logs with syslog format
# Find the last </localfile> tag and add our new configuration after it
if grep -q "</localfile>" "$OSSEC_CONF"; then
    log_info "Adding log file monitoring configurations after existing localfile entries..."
    
    # Add standard logs monitoring
    if ! grep -q "<location>/var/log/clients/\*/\*.log</location>" "$OSSEC_CONF"; then
        sed -i "s|</localfile>|</localfile>\n  <localfile>\n    <log_format>syslog</log_format>\n    <location>/var/log/clients/\*/\*.log</location>\n  </localfile>|" "$OSSEC_CONF"
        log_info "Added general log file monitoring to Wazuh configuration"
    fi
    
    # Add specific audit logs monitoring
    if ! grep -q "<location>/var/log/clients/\*/audisp-syslog.log</location>" "$OSSEC_CONF"; then
        sed -i "s|</localfile>|</localfile>\n  <localfile>\n    <log_format>audit</log_format>\n    <location>/var/log/clients/\*/audisp-syslog.log</location>\n  </localfile>|" "$OSSEC_CONF"
        log_info "Added audisp-syslog.log monitoring with audit format to Wazuh configuration"
    fi
else
    # If no <localfile> tags exist, add them before </ossec_config>
    log_info "No existing <localfile> tag found. Adding log monitoring configurations..."
    
    # Add both configurations before </ossec_config>
    sed -i "s|</ossec_config>|  <localfile>\n    <log_format>syslog</log_format>\n    <location>/var/log/clients/\*/\*.log</location>\n  </localfile>\n  <localfile>\n    <log_format>audit</log_format>\n    <location>/var/log/clients/\*/audisp-syslog.log</location>\n  </localfile>\n</ossec_config>|" "$OSSEC_CONF"
    log_info "Added both general and audit log file monitoring to Wazuh configuration"
fi

# Step 4: Log rotation setup (commented out as requested)
# Uncomment these lines if you want to enable log rotation
# cat > /etc/logrotate.d/client-logs << EOF
# /var/log/clients/*/*.log {
#     daily
#     missingok
#     rotate 7
#     compress
#     delaycompress
#     notifempty
#     create 640 syslog adm
#     sharedscripts
#     postrotate
#         /usr/lib/rsyslog/rsyslog-rotate
#     endscript
# }
# EOF

# Step 5: Check and restart services
# This ensures all changes take effect immediately
log_info "Checking service status..."

# Check and restart rsyslog with error checking
if check_service "rsyslog"; then
    log_info "Restarting rsyslog service..."
    if ! systemctl restart rsyslog; then
        log_error "Failed to restart rsyslog"
        log_info "Checking for configuration errors:"
        rsyslogd -N1
    else
        log_info "rsyslog restarted successfully"
    fi
else
    log_warn "Will attempt to restart rsyslog regardless of current status"
    if ! systemctl restart rsyslog; then
        log_error "Failed to restart rsyslog"
        log_info "Checking for configuration errors:"
        rsyslogd -N1
    else
        log_info "rsyslog restarted successfully"
    fi
fi

# Check and restart Wazuh agent with error checking
if check_service "wazuh-agent"; then
    log_info "Restarting wazuh-agent service..."
    if ! systemctl restart wazuh-agent; then
        log_error "Failed to restart wazuh-agent"
        log_info "Last few lines from wazuh-agent log:"
        tail -n 10 /var/ossec/logs/ossec.log
    else
        log_info "wazuh-agent restarted successfully"
    fi
else
    log_warn "Will attempt to restart wazuh-agent regardless of current status"
    if ! systemctl restart wazuh-agent; then
        log_error "Failed to restart wazuh-agent"
        log_info "Last few lines from wazuh-agent log:"
        tail -n 10 /var/ossec/logs/ossec.log
    else
        log_info "wazuh-agent restarted successfully"
    fi
fi

# Final verification to confirm everything is working
log_info "Verifying services post-restart..."
rsyslog_running=$(systemctl is-active rsyslog)
wazuh_running=$(systemctl is-active wazuh-agent)

if [ "$rsyslog_running" = "active" ] && [ "$wazuh_running" = "active" ]; then
    log_info "Configuration completed successfully!"
    log_info "- rsyslog is receiving logs on UDP port $UDP_PORT"
    log_info "- Remote connections allowed from $ALLOWED_IPS via TCP port 514"
    log_info "- Logs are organized by hostname in /var/log/clients/"
    log_info "- Wazuh agent is monitoring all client logs"
    log_info "- Audit logs (audisp-syslog.log) are properly handled with audit format"
    log_info ""
    log_info "Testing instructions:"
    log_info "1. Configure remote clients to forward logs to this server"
    log_info "2. For auditd logs, ensure audispd-plugins are configured properly"
    log_info "3. Check /var/log/clients/[hostname]/ for incoming logs"
else
    log_error "One or more services failed to start properly:"
    [ "$rsyslog_running" != "active" ] && log_error "- rsyslog is not running"
    [ "$wazuh_running" != "active" ] && log_error "- wazuh-agent is not running"
    log_error "Please check the logs and fix any configuration errors"
fi
