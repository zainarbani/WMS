#!rsc by RouterOS
# RouterOS script: Telkom WMS AIO auto login
# version: v0.8-2022-2-14-release
# authors: zainarbani
# manual: https://github.com/zainarbani/WMS#readme
#

# =========================

# metode login & akun yang didukung:
# WMS venue/violet = venue
# WMS Lite venue/violet = venuelite
# WiSta venue/violet = wista
# wifi.id reguler/voucher/violet = voucher
# wifi.id smartbisnis = smartbisnis
# wifi.id kampus = kampus
# default venue
:local accType "venue";

# username
:local user "ganti";

# password
:local passwd "ganti";

# wlan interface
# eg: wlan1, wlan2
# default wlan1
:local iFace "wlan1";


# =========================



:global WMSRUNNING;
:if ($WMSRUNNING) do={
 :exit ""
} else={
 :set $WMSRUNNING true;
}
:local chkUrl "detectportal.firefox.com";
:local hostSrv "welcome2.wifi.id";
:local pingSrv "1.0.0.1";
:local uA "Safari/537.36";
:local startMsg "WMS: Starting auto login";
:local methodMsg ("WMS: Methods: $accType");
:local successMsg "WMS: Login success";
:local failedMsg "WMS: Login failed";
:local netOk "WMS: Internet connected !";
:local netNok "WMS: Internet disconnected !";
:local wlNok "WMS: WLAN disconnected !";
:local porNok "WMS: Failed to detect login portal !";
:local urlEncoder do={
 :local urlEncoded;
 :for i from=0 to=([:len $1] - 1) do={
  :local char [:pick $1 $i]
  :if ($char = " ") do={:set $char "%20"}
  :if ($char = "@") do={:set $char "%40"}
  :set urlEncoded ($urlEncoded . $char)
 }
 :return $urlEncoded;
}
:if ([/interface get [/interface find name=$iFace] running]) do={
 :if ([/ping $pingSrv interval=1 count=2 interface=$iFace] = 0) do={
  :log warning $netNok;
  :log warning $startMsg;
  :log warning $methodMsg;
  /ip firewall nat disable [find where out-interface=$iFace]
  /ip dns cache flush
  /ip dns static remove [find where comment=to-wms]
  /ip dhcp-client set [find interface=$iFace] use-peer-dns=yes
  /ip dhcp-client release [find interface=$iFace]
  :delay 5;
  :local gw [/ip dhcp-client get [find where interface=$iFace] gateway];
  /ip route add gateway=("$gw%$iFace") dst-address=$pingSrv comment=to-wms
  :foreach o in={$chkUrl; $hostSrv} do={
   /ip firewall address-list add list=wifiid address=$o timeout=15s
   :delay 2;
   :foreach p in=[/ip firewall address-list find comment=$o] do={
    :local addr [/ip firewall address-list get $p address];
    /ip route add gateway=("$gw%$iFace") dst-address=$addr comment=to-wms
    /ip dns static add name=$o address=$addr type=A comment=to-wms
   }
  }
  :do {
   :set $detectUrl ([/tool fetch url=("http://$chkUrl") output=user as-value]->"data");
   :delay 1;
  } on-error={
   :do {
    :execute file=detectUrl.txt script=("/tool fetch url=http://$chkUrl");
    :delay 1;
    :set $detectUrl [:file get detectUrl.txt contents];
    :file remove detectUrl.txt;
   } on-error={}
  }
  :if ($detectUrl != "success\n") do={
   :set $portalUrl [$urlEncoder [:pick $detectUrl [:len [:pick $detectUrl 0 [:find $detectUrl "http://w"]]] [:find $detectUrl "\">"]]];
   :if ([:len $portalUrl] < 20) do={
    :log warning $porNok;
   } else={
    :do {
     :local Udata ([/tool fetch url=$portalUrl output=user as-value]->"data");
     :local kUser [:pick $user 0 [:find $user "@"]];
     :if (($accType = "venue") || ($accType = "venuelite") || ($accType = "wista")) do={
      :if ([:len $kUser] = [:find $user "@violet"]) do={
       :set $Uniq $user;
      } else={
       :if (($accType = "venue") || ($accType = "venuelite")) do={
        :if ($accType = "venuelite") do={
         :set $Ven "wmslite";
        }
        :if ($accType = "venue") do={
         :set $Ven "wms";
        }
        :set $vID [:pick $Udata [:len [:pick $Udata 0 [:find $Udata $Ven]]] [:find $Udata "');\n"]];
        :if ([:len $vID] = 0) do={
         :set $vID [:pick $Udata [:len [:pick $Udata 0 [:find $Udata $Ven]]] [:find $Udata ".000');\n"]];
        }
        :set $Uniq ("$user.ULd9@$vID");
        :if ([:find $Udata ".000');\n"]) do={
         :set $Uniq ("$Uniq.000");
        }
       }
       :if ($accType = "wista") do={
        :set $Uniq ("$user@violet");
       }
      }
      :set $payloads [$urlEncoder ("username_=$user&username=$Uniq&password=$passwd")];
      :local Url [:pick $Udata [:len [:pick $Udata 0 [:find $Udata "auth/"]]] [:find $Udata "&landURL"]];
      :set $iUrl [$urlEncoder ("http://$hostSrv/wms/$Url")];
     }
     :if (($accType = "voucher") || ($accType = "smartbisnis") || ($accType = "kampus")) do={
      :local Uid [:pick $user [:len $kUser] [:len $user]];
      :if ($accType = "voucher") do={
       :if ([:len $kUser] = [:find $user "@violet"]) do={
        :set $Uniq $user;
       } else={
        :set $Uniq ("$user@spin2");
       }
      }
      :if ($accType = "smartbisnis") do={
       :set $Uniq ("$user@com.smartbisnis");
      }
      :if ($accType = "kampus") do={
       :set $Uniq ("$user.vmgmt@wms.00000000.000");
       :local kampusid {{"@ut.ac.id";"$user@com.ut"};{"@unej";"$kUser@com.unej"};\
        {"@umaha";"$kUser@com.umaha"};{"@trisakti";"$kUser@com.trisakti"};\
        {"@itdel";"$kUser@com.itdel"};{"@polije";"$kUser@com.polije"};\
        {"@unsiq";"$kUser@com.unsiq"}\
       }
       :foreach x in=$kampusid do={
        :if ($Uid = ($x->0)) do={
         :set $Uniq ($x->1);
        }
       }
      }
      :set $payloads [$urlEncoder ("username=$Uniq&password=$passwd")];
      :local Url [:pick $Udata [:len [:pick $Udata 0 [:find $Udata "check_login"]]] [:find $Udata "@wifi.id&load_wp='+load_time;"]];
      :set $iUrl [$urlEncoder ("https://$hostSrv/authnew/login/$Url@wifi.id")];
     }
    } on-error={}
    :delay 1;
    :if ([/ping $pingSrv interval=1 count=2 interface=$iFace] > 1) do={
     :log warning $successMsg;
    } else={
     :do {
      :set $result ([/tool fetch http-method=post http-header-field=("Referer: $portalUrl, User-Agent: $uA") http-data=$payloads host=$hostSrv url=$iUrl output=user as-value]->"data");
     } on-error={}
     :delay 1;
     :if ([/ping $pingSrv interval=1 count=2 interface=$iFace] > 1) do={
      :log warning $successMsg;
     } else={:log warning $failedMsg}
    }
   }
  } else={:log warning $netOk}
  /ip route remove [find where comment=to-wms]
  /ip dns static remove [find where comment=to-wms]
  /ip firewall nat enable [find where out-interface=$iFace]
 }
} else={:log warning $wlNok}
:set $WMSRUNNING false;
