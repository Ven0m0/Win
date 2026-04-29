

NetTCPSetting | Select SettingName, CongestionProvider
netsh int tcp set supplemental template=Internet congestionprovider=BBR2
netsh int tcp set supplemental template=InternetCustom congestionprovider=BBR2
netsh int tcp set supplemental template=Datacenter congestionprovider=BBR2
netsh int tcp set supplemental template=DatacenterCustom congestionprovider=BBR2
netsh int tcp set supplemental template=Compat congestionprovider=BBR2
netsh int ipv6 set global loopbacklargemtu=disable
netsh int ipv4 set global loopbacklargemtu=disable