#!rsc by RouterOS
# RouterOS script: Wireless mac-address generator
# version: v0.1-2021-09-26-release
# authors: zainarbani
# manual: https://github.com/zainarbani/WMS#readme
#

# ==========================

# interface name
:local iFace "wlan1";

# ==========================

:log warning ("MACGEN: $iFace current mac: " . [/interface wireless get [find name=$iFace] mac-address]);
:local randomHex ([/certificate scep-server otp generate minutes-valid=0 as-value]->"password");
:local newMac;
:local pos 0;
:for i from=0 to=5 do={
 :set $newMac ($newMac . [:pick $randomHex $pos ($pos + 2)] . ":");
 :set $pos ($pos + 2);
}
:set $newMac [:pick $newMac 0 ([:len $newMac] - 1)];
/interface wireless set [find name=$iFace] mac-address=$newMac
:log warning ("MACGEN: $iFace new mac: " . [/interface wireless get [find name=$iFace] mac-address]);
