TODO
====

- [x] Test the installation of Kolide-Windows-Launcher -> success
- [x] Strip down our Kolide-Linux-Launcher package to something that will run anywhere (tar.gz)
- [x] Build ping query
- [ ] Build required Banana dashboards
- [ ] Installation of Kolide on Philipp´s server
- [ ] IPv6 knowledge update
- [x] Create SSH-key
- [ ] Enhance queries
  - [ ] ARP
  - [ ] authorized_keys
  - [ ] Iptables
  - [ ] Kernel-Modules
  - [ ] Listening ports
  - [ ] Connections
  - [ ] Routes
  - [ ] Shell-history

- [ ] Borg
  - [x] Strip down and implement Björn´s hardening script
  - [x] Kolide-Linux-Launcher installation
  - [x] Package updates
  - [x] Dump listening daemons
  - [x] Dump cron jobs
  - [x] Dump firewall rules
  - [x] Dump arp cache
  - [x] Dump MACs of system
  - [x] Check SSHD configuration
  - [ ] Init-checks
  - [x] Copy important binaries as backup
  - [ ] Syslog config update for redirect over network
  - [x] Lynis installation and execution
  - [x] Run some webserver scan on open ports -> manually
- [ ] Install own client with Kali, need harddisk first

Osquery hints
-------------

Packed with $ tar -czf osquery.tar osquery --owner=0 --group=0
