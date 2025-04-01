Kolide-Launcher installation on Windows
=======================================

Installation
------------

- SSH into the Kolide Fleet server
- cd into /home/centos/go/src/github.com/kolide/launcher
- run PATH=$PATH:/usr/local/go/bin GOPATH=/home/centos/go GOCACHE=/home/centos/.cache make package-builder-windows
- copy build/windows/package-builder.exe to a windows host
- Unpack wixtoolset 3.11 on the Windows host to c:\wix311 from [here](https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip)
- Execute the package-builder.exe as follows: package-builder.exe make -enroll_secret=abc -hostname=localhost:443 -targets windows-service-msi -debug true -insecure true
- Install the resulting file
- Check if the Windows service is up and running

Troubleshooting
---------------

- Installation path is C:\Program Files\Kolide\Launcher-launcher, service name is "LauncherLauncherSvc", secrets and target host data is saved there
- Logs are stored in Windows-Event-System, start eventvwr, navigate to Windows-Protocols / Application and/or Security
