# Telkom WMS AIO auto login
[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)

## Supported methods
 - WMS venue/violet
 - WMS Lite venue/violet
 - WiSta venue/violet
 - wifi.id reguler/voucher/violet
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
    start-time=startup interval=20s
```

Wireless mac-address generator:
```
/system script
add name="MACGEN" dont-require-permission=yes source=([/tool fetch url="https://raw.githubusercontent.com/zainarbani/WMS/master/MACGEN.rsc" output=user as-value]->"data")
```

We poor peeps would do literally anything
```
/interface wireless set [/interface find name=wlan1] radio-name="iPhone 13 Pro Max"
```
