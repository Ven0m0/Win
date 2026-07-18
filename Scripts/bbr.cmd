@echo off
:: bbr2 might break steam
netsh int tcp set supplemental template=internet congestionprovider=bbr2
:: netsh int tcp set supplemental template=internet congestionprovider=cubic
netsh int tcp set global rss=enabled
netsh int tcp set global fastopen=enabled
netsh int tcp set global ecncapability=enabled
exit
