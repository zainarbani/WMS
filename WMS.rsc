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

# Nexmo WhatsApp API
# https://dashboard.nexmo.com/messages/sandbox
# use Bot: true = yes | flase = no
# default false
:local useBot false;

# Nexmo API key
:local apiKey "";

# Nexmo API secret
:local apiSec "";

# Nexmo Bot Number
:local botNum "";

# Nexmo User Number
:local userNum "";

# =========================



:foreach o in={"WMS"; "WMS2",} do={
 :if ([:len [/system script job find where script=$o]] > 1) do={
  :exit ""
 }
}
:local Board [/system resource get board-name];
:local cpuRes [/system resource get cpu-load];
:local Ident [/system identity get name];
:local wlSid [/interface wireless get [find where name=wlan1] ssid];
:local wlSignal [/interface wireless registration-table get [find where interface=$iFace] signal-strength-ch0];
:local wlCcq [/interface wireless registration-table get [find where interface=$iFace] tx-ccq];
:local wlTx [/interface wireless registration-table get [find where interface=$iFace] tx-rate];
:local wlRx [/interface wireless registration-table get [find where interface=$iFace] rx-rate];
:local chkUrl "detectportal.firefox.com";
:local hostSrv "welcome2.wifi.id";
:local pingSrv "8.8.8.8";
:local uA "Safari/537.36";
:local startMsg "WMS: Starting auto login";
:local methodMsg ("WMS: Methods: $accType");
:local successMsg "WMS: Login success";
:local failedMsg "WMS: Login failed";
:local netOk "WMS: Internet connected !";
:local netNok "WMS: Internet disconnected !";
:local wlNok "WMS: WLAN disconnected !";
:local porNok "WMS: Failed to detect login portal !";
:local successBot ("Auto Login Success\\n\\nRouter: $Board\\nIdentity: $Ident\\nCPU Usage: $cpuRes %\\n\\nWLAN Info:\\nSSID: $wlSid\\nStrength: $wlSignal dBm\\nCCQ: $wlCcq %\\nTX: $wlTx\\nRX: $wlRx");
:local sendBot do={
 :do {
  :local cUrl "https://messages-sandbox.nexmo.com/v1/messages";
  :local logoUrl "https://raw.githubusercontent.com/zainarbani/WMS/main/logo.png";
  :local bHead "{content-type: application/json}";
  :local bDat ("{\"from\": \"$3\", \"to\": \"$4\", \"message_type\": \"image\", \"image\": {\"url\": \"$logoUrl\", \"caption\": \"$5\"}, \"channel\": \"whatsapp\"}");
  /tool fetch http-method=post url=$cUrl http-header-field=$bHead http-data=$bDat user=$1 password=$2 output=none
 } on-error={}
}
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
       :if ($Uid = "@ut.ac.id") do={
        :set $Uniq ("$user@com.ut");
       }
       :if ($Uid = "@unej") do={
        :set $Uniq ("$kUser@com.unej");
       }
       :if ($Uid = "@umaha") do={
        :set $Uniq ("$kUser@com.umaha");
       }
       :if ($Uid = "@trisakti") do={
        :set $Uniq ("$kUser@com.trisakti");
       }
       :if ($Uid = "@itdel") do={
        :set $Uniq ("$kUser@com.itdel");
       }
       :if ($Uid = "@polije") do={
        :set $Uniq ("$kUser@com.polije");
       }
       :if ($Uid = "@unsiq") do={
        :set $Uniq ("$kUser@com.unsiq");
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
     :if ($useBot) do={
      $sendBot $apiKey $apiSec $botNum $userNum $successBot;
     }
    } else={
     :do {
      :set $result ([/tool fetch http-method=post http-header-field=("Referer: $portalUrl, User-Agent: $uA") http-data=$payloads host=$hostSrv url=$iUrl output=user as-value]->"data");
     } on-error={}
     :delay 1;
     :if ([/ping $pingSrv interval=1 count=2 interface=$iFace] > 1) do={
      :log warning $successMsg;
      :if ($useBot) do={
       $sendBot $apiKey $apiSec $botNum $userNum $successBot;
      }
     } else={:log warning $failedMsg}
    }
   }
  } else={:log warning $netOk}
  /ip route remove [find where comment=to-wms]
  /ip dns static remove [find where comment=to-wms]
  /ip firewall nat enable [find where out-interface=$iFace]
 }
} else={:log warning $wlNok}
