Changes root password for hosts


hosts.txt file format: 
```
username:password:ip
root:root:10.10.10.10
root:toor:10.10.10.11
```

For ssh, use: 
```ssh -o StrictHostKeyChecking=no -i /path/to/key username@IP```

Ideally lets run per segment, so we are checking if something fails and are able to troubleshoot


# Run procedure for Hour One
OF: On Fail

1. Run script to Install wazuh on VM on "Our VM" <br>
    OF: Bruno troubleshoots

1. Run script to install syslog / auditd server on "Our VM"<br>
    OF: Pranav troubleshoots, installs manually

1. Run script to install FTP server on "Our VM" <br>
    OF: Pranav troubleshoots, installs manually

1. Run script to change root password + copy ssh key to hosts<br>
    OF: Segment caretaker does it manually

1. Run script to install wazuh agent'<br>
    OF: Segment caretaker does it manually 

