# Wazuh

wazuh manager linux ip: 100.101.202.10


# dont use, only for reference: 

wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.11.1-1_amd64.deb && sudo WAZUH_MANAGER='192.168.10.10' dpkg -i ./wazuh-agent_4.11.1-1_amd64.deb

## Actual command

wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.11.1-1_amd64.deb && sudo WAZUH_MANAGER='100.101.202.10' dpkg -i ./wazuh-agent_4.11.1-1_amd64.deb

## BPS INT automation

`ansible-playbook -i bpsIntHosts bpsintAuto.yml`

This will install Wazuh, change root password and add the skeleton key to authorized_keys in /root/.ssh.