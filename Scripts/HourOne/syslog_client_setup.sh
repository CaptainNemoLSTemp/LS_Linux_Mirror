#!/bin/bash
set -euo pipefail

# Variables
LOG_SERVER="192.168.10.10" # Central_Server_IP
LOG_PORT="514" # UDP_Port
LOG_LINE="*.*   @${LOG_SERVER}:${LOG_PORT}" # Proper rsyslog format
BACKUP_SUFFIX=".bak-$(date +%Y%m%d%H%M%S)"

RSYSLOG_CONFIG="/etc/rsyslog.d/50-default.conf"
AUDITD_CONF="/etc/audisp/plugins.d/syslog.conf"
AUDITD_CONF_ALT="/etc/audit/plugins.d/syslog.conf" # Alternative path for newer systems
AUDIT_RULES="/etc/audit/rules.d/audit.rules"

# Logging functions
log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2; }
log_warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*" >&2; }

# Get client IP addresses (both IPv4 and IPv6)
get_client_ips() {
    local ip_info=""
    
    # Try to get IPv4 address
    local ipv4
    ipv4=$(hostname -I 2>/dev/null | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -1)
    if [ -z "$ipv4" ]; then
        ipv4=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d'/' -f1 | head -1)
    fi
    
    # Try to get IPv6 address
    local ipv6
    ipv6=$(hostname -I 2>/dev/null | grep -oE '\b([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b' | head -1)
    if [ -z "$ipv6" ]; then
        ipv6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d'/' -f1 | grep -v '^fe80' | head -1)
    fi
    
    # Format the output
    if [ -n "$ipv4" ] && [ -n "$ipv6" ]; then
        ip_info="IPv4: $ipv4, IPv6: $ipv6"
    elif [ -n "$ipv4" ]; then
        ip_info="IPv4: $ipv4"
    elif [ -n "$ipv6" ]; then
        ip_info="IPv6: $ipv6"
    else
        ip_info="unknown"
    fi
    
    echo "$ip_info"
}

CLIENT_IPS=$(get_client_ips)

log_info "Starting log forwarding configuration script."

# Check for required packages
missing_packages=()

# Check for rsyslog
if ! command -v rsyslogd &> /dev/null; then
    missing_packages+=("rsyslog")
fi

# Check for auditd
if ! command -v auditctl &> /dev/null; then
    missing_packages+=("auditd")
fi

# Check for audispd-plugins (check for either configuration file)
if [ ! -f "$AUDITD_CONF" ] && [ ! -f "$AUDITD_CONF_ALT" ]; then
    missing_packages+=("audispd-plugins")
fi

# If any packages are missing, prompt to install
if [ ${#missing_packages[@]} -gt 0 ]; then
    log_error "The following required packages are not installed: ${missing_packages[*]}"
    log_info "Please install them using your package manager:"
    
    if command -v apt-get &> /dev/null; then
        log_info "sudo apt-get update && sudo apt-get install ${missing_packages[*]}"
    elif command -v yum &> /dev/null; then
        log_info "sudo yum install ${missing_packages[*]}"
    elif command -v dnf &> /dev/null; then
        log_info "sudo dnf install ${missing_packages[*]}"
    else
        log_info "Please use your system's package manager to install: ${missing_packages[*]}"
    fi
    
    log_info "After installing the required packages, please run this script again."
    exit 1
fi

# Check required commands
for cmd in rsyslogd systemctl logger auditctl; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command $cmd not found! Please install it."
        exit 1
    fi
done

# Configure Rsyslog log forwarding
if [ ! -f "$RSYSLOG_CONFIG" ]; then
    log_error "Rsyslog config file $RSYSLOG_CONFIG not found! Ensure rsyslog is installed."
    exit 1
fi

if ! grep -qF "$LOG_LINE" "$RSYSLOG_CONFIG"; then
    log_info "Adding log forwarding configuration to $RSYSLOG_CONFIG"
    echo -e "\n# Added by log forwarding script\n$LOG_LINE" | sudo tee -a "$RSYSLOG_CONFIG" > /dev/null
else
    log_info "Log forwarding configuration already exists in $RSYSLOG_CONFIG"
fi

# Restart Rsyslog service
if ! systemctl is-active --quiet rsyslog; then
    log_info "Rsyslog is not running. Starting it..."
    if ! sudo systemctl start rsyslog.service; then
        log_error "Failed to start rsyslog.service!"
        exit 1
    fi
fi

log_info "Restarting rsyslog service..."
if ! sudo systemctl restart rsyslog.service; then
    log_error "Failed to restart rsyslog.service!"
    exit 1
fi

# Check for active audit rules
if ! sudo auditctl -l 2>/dev/null; then
    log_warn "No audit rules are currently defined in the system"
    log_info "You can take a look at: https://github.com/Neo23x0/auditd/blob/master/audit.rules"
    log_info "Download the audit.rules file and place it in $AUDIT_RULES"
    log_info "You can use commands like:"
    log_info "  sudo mkdir -p $(dirname "$AUDIT_RULES")"
    log_info "  sudo curl -o $AUDIT_RULES https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules"
    log_info "  sudo augenrules --load  # To load the new rules"
    log_info "  # OR"
    log_info "  sudo wget -O $AUDIT_RULES https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules"
    log_info "  sudo augenrules --load  # To load the new rules"
    
    read -p "Would you like to continue without audit rules? (y/n): " continue_without_rules
    if [[ ! "$continue_without_rules" =~ ^[Yy] ]]; then
        log_info "Please download and apply the audit rules file and run this script again."
        exit 1
    fi
fi

# Check for auditd configuration file existence and set the correct path
AUDIT_CONF_PATH=""
if [ -f "$AUDITD_CONF" ]; then
    AUDIT_CONF_PATH="$AUDITD_CONF"
    log_info "Found auditd configuration at $AUDITD_CONF"
elif [ -f "$AUDITD_CONF_ALT" ]; then
    AUDIT_CONF_PATH="$AUDITD_CONF_ALT"
    log_info "Found auditd configuration at alternative path $AUDITD_CONF_ALT"
else
    log_warn "Auditd configuration file not found at either path. Skipping auditd configuration."
fi

# Configure Auditd to forward logs to syslog (if auditd is installed)
if [ -n "$AUDIT_CONF_PATH" ]; then
    
    log_info "Updating auditd syslog plugin configuration..."
    sudo sed -i -E 's/^active = .*/active = yes/; s/^args = .*/args = LOG_INFO/; s/^format = .*/format = string/' "$AUDIT_CONF_PATH"
    
    # Check if auditd is running and start if necessary
    if ! systemctl is-active --quiet auditd; then
        log_info "Auditd is not running. Attempting to start it..."
        if ! sudo systemctl start auditd; then
            log_warn "Failed to start auditd service! This may be expected if auditd is not installed."
        fi
    else
        log_info "Auditd service is already running."
    fi
    
    # Restart auditd service
    log_info "Restarting auditd service..."
    if ! sudo systemctl restart auditd; then
        log_warn "Failed to restart auditd.service! This may be expected if auditd is not installed."
    else
        log_info "Auditd service restarted successfully."
    fi
fi

# Briefly wait for logs to update 
sleep 2

# Check rsyslog logs for issues
log_info "Verifying rsyslog configuration..."
if sudo journalctl -u rsyslog.service --since "1 minute ago" --no-pager | grep -iE "error|failed|cannot connect"; then
    log_error "Issues detected in rsyslog logs!"
    exit 1
fi

# Test log forwarding
log_info "Testing log forwarding..."
TEST_MSG="Test log forwarding from $CLIENT_IP to central server $(date)"
logger "$TEST_MSG"

log_info "Script execution completed successfully."
echo
log_info "IMPORTANT: Please verify logs are being received on the central log server."
log_info "You may need to check for the test message: \"$TEST_MSG\""

exit 0