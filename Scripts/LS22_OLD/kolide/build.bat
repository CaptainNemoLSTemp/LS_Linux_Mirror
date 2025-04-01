@echo off

package-builder.exe make -enroll_secret=i89Jl2mQk0GXDhYouq1sgl1rmRNrg8Fe -hostname=localhost.localdomain:1234 -targets windows-service-msi -debug true -insecure true

echo DO NOT FORGET TO ADD THE CA CERT TO THE TRUSTED STORE!!!

pause