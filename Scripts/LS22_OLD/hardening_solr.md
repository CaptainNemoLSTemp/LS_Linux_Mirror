# Hardening of SolR

- Set root password!
- Update fleet.pem
- Setup iptables, listing here:

  ```bash

  #!/bin/bash

  function ipt
  {
    echo Exec of: $@
    iptables-legacy $@
  }

  function ipt6
  {
    echo Exec of: $@
    ipt6ables-legacy $@
  }

  # v4
  ipt -P INPUT DROP
  ipt -F INPUT
  ipt -F OUTPUT

  ipt -A INPUT -i lo -j ACCEPT
  ipt -A INPUT -i ens34 -p tcp --dport 22 -j ACCEPT
  ipt -A INPUT -i ens34 -p tcp --dport 1234 -j ACCEPT

  ipt -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ipt -A INPUT -j LOG --log-prefix INPUT_failed_for_

  # v6
  ipt6 -P INPUT DROP
  ipt6 -F INPUT
  ipt6 -F OUTPUT

  ipt6 -A INPUT -i lo -j ACCEPT
  ipt6 -A INPUT -i ens34 -p tcp --dport 22 -j ACCEPT
  ipt6 -A INPUT -i ens34 -p tcp --dport 1234 -j ACCEPT

  ipt6 -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ipt6 -A INPUT -j LOG --log-prefix INPUT_failed_for_
  ```
