# Telkom WMS AIO auto login
[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

## Supported methods
 - WMS venue
 - WMS Lite venue
 - wifi.id normal/voucher/violet
 - wifi.id smartbisnis
 - wifi.id kampus

## Requirements
 - <strike>RouterOS > v6.44</strike> Just keep ur fckn RouterOS updated.

## Installation

Download auto login:
```
/system script
add name="WMS" dont-require-permission=yes source=([/tool fetch url="https://raw.githubusercontent.com/zainarbani/WMS/master/WMS.rsc" output=user as-value]->"data")
```

Create scheduler:
```
/system scheduler
add name=WMS on-event="/system script run WMS" policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    start-time=startup
```

Wireless mac-address generator:
```
/system script
add name="MACGEN" dont-require-permission=yes source=([/tool fetch url="https://raw.githubusercontent.com/zainarbani/WMS/master/MACGEN.rsc" output=user as-value]->"data")
```
