# Manual installation of Osquery client on Linux

Hopefully we do not need to do a manual install on the linux machines. Instead we try to do this automatically via SSH.
If this does not work we have to do it manually:

- Copy the archive to the remote machine, e.g. to /tmp
- tar -C /root/ -xzf /tmp/osquery.tar.gz
- cd /root/osquery
- ./launcher -config ./launcher.flags

