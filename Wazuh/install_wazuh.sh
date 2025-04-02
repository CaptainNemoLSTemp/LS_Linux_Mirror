#!/bin/bash

# Wazuh Manager IP (Bitte anpassen)
WAZUH_MANAGER_IP="100.101.202.10"

# Erkennen der Distribution
if [ -f /etc/debian_version ]; then
    OS="debian"
    PKG_MANAGER="apt-get"
elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    PKG_MANAGER="dnf"
else
    echo "Nicht unterstütztes Betriebssystem"
    exit 1
fi

# Wazuh-Repository hinzufügen
if [ "$OS" == "debian" ]; then
    curl -sO https://packages.wazuh.com/key/GPG-KEY-WAZUH
    apt-key add GPG-KEY-WAZUH
    echo "deb [trusted=yes] https://packages.wazuh.com/4.x/apt/ stable main" > /etc/apt/sources.list.d/wazuh.list

    $PKG_MANAGER update
elif [ "$OS" == "redhat" ]; then
    rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
    cat > /etc/yum.repos.d/wazuh.repo <<EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=EL-Wazuh
baseurl=https://packages.wazuh.com/4.x/yum/
EOF
fi

# Wazuh-Agent installieren
$PKG_MANAGER install -y wazuh-agent

# Wazuh-Agent konfigurieren
sed -i "s|<address>.*</address>|<address>$WAZUH_MANAGER_IP</address>|" /var/ossec/etc/ossec.conf

# Agent starten und aktivieren
systemctl enable wazuh-agent --now

echo "Wazuh-Agent erfolgreich installiert und mit $WAZUH_MANAGER_IP verbunden."
