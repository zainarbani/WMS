#!rsc by RouterOS
# RouterOS script: Telkom WMS AIO auto login
# version: v0.7-2021-11-27-release
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

# CallMeBot WhatsApp API
# https://www.callmebot.com/blog/free-api-whatsapp-messages/
# use CallMeBot: true = yes | flase = no, default false
:local useCallMeBot false;

# CallMeBot API key
:local cmbApiKey "";

# CallMeBot phone number
:local cmbPhone "";

# =========================


:if ([:len [/system script job find where script=WMS]] > 1) do={
 :exit ""
}
:local Date [/system clock get date];
:local Time [/system clock get time];
:local Board [/system resource get board-name];
:local chkUrl "http://detectportal.firefox.com/success.txt";
:local pingSrv "9.9.9.9";
:local uA "Safari/537.36";
:local successMsg "WMS: Login success";
:local failedMsg "WMS: Login failed";
:local successBot ("MikroTik $Board%0AWMS: Login success%0ATime: $Time%0ADate: $Date");
:local detectUrl;
:local portalUrl;
:local result;
:local payloads;
:local iUrl;
:local Uniq;
:local sendCallMeBot do={
 :do {
  :local cUrl ("https://api.callmebot.com/whatsapp.php\?phone=$1&text=$3&apikey=$2");
  /tool fetch http-header-field=("User-Agent: $uA") url=$cUrl output=none
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
  :log warning "WMS: Internet disconnected !";
  :log warning "WMS: Starting auto login";
  :log warning ("WMS: Methods: $accType");
  /ip firewall nat disable [find where out-interface=$iFace]
  /ip dns cache flush
  /ip dhcp-client release [find interface=$iFace]
  :delay 5;
  :local gw [/ip dhcp-client get [find where interface=$iFace] gateway];
  /ip route add gateway=("$gw%$iFace") dst-address=9.9.9.9 comment=to-wms
  :foreach o in={"welcome2.wifi.id"; "detectportal.firefox.com"} do={
   /ip firewall address-list add list=wifiid address=$o timeout=15s
   :delay 2;
   :foreach p in=[/ip firewall address-list find comment=$o] do={
    :local addr [/ip firewall address-list get $p address];
    /ip route add gateway=("$gw%$iFace") dst-address=$addr comment=to-wms
    /ip dns static add name=$o address=$addr type=A comment=to-wms
   }
  }
  :do {
   :set $detectUrl ([/tool fetch url=$chkUrl output=user as-value]->"data");
  } on-error={
   :do {
    :execute file=detectUrl.txt script=("/tool fetch url=$chkUrl");
    :delay 1;
    :set $detectUrl [:file get detectUrl.txt contents];
    :file remove detectUrl.txt;
   } on-error={}
  }
  :if ($detectUrl != "success\n") do={
   :set $portalUrl [$urlEncoder [:pick $detectUrl [:len [:pick $detectUrl 0 [:find $detectUrl "http://w"]]] [:find $detectUrl "\">"]]];
   :if ([:len $portalUrl] < 20) do={
    :log warning "WMS: Failed to detect login portal !";
   } else={
    :do {
     :local Udata ([/tool fetch url=$portalUrl output=user as-value]->"data");
     :local kUser [:pick $user 0 [:find $user "@"]];
     :if (($accType = "venue") || ($accType = "venuelite") || ($accType = "wista")) do={
      :if ([:len $kUser] = [:find $user "@violet"]) do={
       :set $Uniq $user;
      } else={
       :if ($accType = "venue") do={
        :set $Uniq ("$user.ULd9@".[:pick $Udata [:len [:pick $Udata 0 [:find $Udata "wms"]]] [:find $Udata ".000"]]."000");
       }
       :if ($accType = "venuelite") do={
        :set $Uniq ("$user.ULd9@".[:pick $Udata [:len [:pick $Udata 0 [:find $Udata "wmslite"]]] [:find $Udata "');"]]);
       }
       :if ($accType = "wista") do={
        :set $Uniq ("$user@violet");
       }
      }
      :set $payloads [$urlEncoder ("username_=$user&username=$Uniq&password=$passwd")];
      :local Url [:pick $Udata [:len [:pick $Udata 0 [:find $Udata "auth/"]]] [:find $Udata "&landURL"]];
      :set $iUrl [$urlEncoder ("http://welcome2.wifi.id/wms/$Url")];
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
      :set $iUrl [$urlEncoder ("https://welcome2.wifi.id/authnew/login/$Url@wifi.id")];
     }
    } on-error={}
    :delay 1;
    :if ([/ping $pingSrv interval=1 count=2 interface=$iFace] > 1) do={
     :log warning $successMsg;
     :if ($useCallMeBot) do={
      $sendCallMeBot $cmbPhone $cmbApiKey [$urlEncoder $successBot];
     }
    } else={
     :do {
      :set $result ([/tool fetch http-method=post http-header-field=("Referer: $portalUrl, User-Agent: $uA") http-data=$payloads host="welcome2.wifi.id" url=$iUrl output=user as-value]->"data");
      :delay 2;
     } on-error={}
     :if ([/ping $pingSrv interval=1 count=2 interface=$iFace] > 1) do={
      :log warning $successMsg;
      :if ($useCallMeBot) do={
       $sendCallMeBot $cmbPhone $cmbApiKey [$urlEncoder $successBot];
      }
     } else={:log warning $failedMsg}
    }
   }
  } else={:log warning "WMS: Internet connected"}
  /ip route remove [find where comment=to-wms]
  /ip dns static remove [find where comment=to-wms]
  /ip firewall nat enable [find where out-interface=$iFace]
 }
} else={:log warning "WMS: WLAN disconnected !"}
