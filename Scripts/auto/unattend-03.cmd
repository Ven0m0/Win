@echo off
:: unattend-03.cmd - Additional system optimizations for Windows Setup
:: This script runs during the specialize pass

powercfg.exe /hibernate off
fsutil behavior set DisableLastAccess 1
fsutil behavior set disable8dot3 1
fsutil behavior set disableencryption 1
fsutil behavior set disablecompression 1
fsutil behavior set encryptpagingfile 0