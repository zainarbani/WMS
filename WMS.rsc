#!rsc by RouterOS
# RouterOS script: Telkom WMS AIO auto login
# version: v0.4-2021-10-3-release
# authors: zainarbani
# manual: https://github.com/zainarbani/WMS#readme
#

# =========================

# metode login & akun yang didukung:
# WMS venue = wms
# WMS Lite venue = wmslite
# wifi.id normal/voucher/violet = voucher
# wifi.id smartbisnis = smartbisnis
# wifi.id kampus = kampus
# default wms
:local accType "wms";

# username
:local user "ganti";

# password
:local passwd "ganti";

# wlan interface
# eg: wlan1, wlan2
# default wlan1
:local iFace "wlan1";

# =========================

:global urlEncoder do={
 :local urlEncoded;
 :for i from=0 to=([:len $1] - 1) do={
  :local char [:pick $1 $i]
  :if ($char = " ") do={:set $char "%20"}
  :if ($char = "@") do={:set $char "%40"}
  :set urlEncoded ($urlEncoded . $char)
 }
 :return $urlEncoded;
}
:while (true) do={
 :local chkUrl "http://detectportal.firefox.com/success.txt";
 :local detectUrl;
 :local portalUrl;
 :local result;
 :local payloads;
 :local iUrl;
 :delay 30;
 :if ([/interface get [/interface find name=$iFace] running]) do={
  :if ([/ping 8.8.8.8 interval=1 count=1] = 0) do={
   :log warning "WMS: Internet disconnected !";
   :log warning "WMS: Starting auto login";
   :log warning ("WMS: Methods: $accType");
   /ip firewall nat disable [find where out-interface=$iFace]
   /ip dns cache flush
   /ip dhcp-client release [find interface=$iFace]
   :delay 10;
   :do {
    :set $detectUrl ([/tool fetch url=$chkUrl output=user as-value]->"data");
   } on-error={
    :execute file=detectUrl.txt script=("/tool fetch url=$chkUrl");
    :delay 5;
    :set $detectUrl [:file get detectUrl.txt contents];
    :file remove detectUrl.txt;
   }
   :if ($detectUrl != "success\n") do={
    :set $portalUrl [$urlEncoder [:pick $detectUrl [:len [:pick $detectUrl 0 [:find $detectUrl "http://w"]]] [:find $detectUrl "\">"]]];
    :if ([:len $portalUrl] < 20) do={
     :log warning "WMS: Failed to detect login portal !";
    } else={
     :do {
      :local Udata ([/tool fetch url=$portalUrl output=user as-value]->"data");
      :if (($accType = "wms") || ($accType = "wmslite")) do={
       :local Url [:pick $Udata [:len [:pick $Udata 0 [:find $Udata "auth/"]]] [:find $Udata "&landURL"]];
       :local Uid [:pick $Udata [:len [:pick $Udata 0 [:find $Udata "wms"]]] [:find $Udata ".000"]];
       :set $payloads [$urlEncoder ("username_=$user&autologin_time=86000&username=$user.ULd9@$Uid.000&password=$passwd")];
       :if ($accType = "wmslite") do={
        :local Uid [:pick $Udata [:len [:pick $Udata 0 [:find $Udata "wmslite"]]] [:find $Udata "');"]];
        :set $payloads [$urlEncoder ("username_=$user&autologin_time=86000&username=$user.ULd9@$Uid&password=$passwd")];
       }
       :set $iUrl [$urlEncoder ("http://welcome2.wifi.id/wms/$Url")];
      }
      :if (($accType = "voucher") || ($accType = "smartbisnis") || ($accType = "kampus")) do={
       :local kUser [:pick $user 0 [:find $user "@"]];
       :local Uid [:pick $user [:len $kUser] [:len $user]];
       :local Url [:pick $Udata [:len [:pick $Udata 0 [:find $Udata "check_login"]]] [:find $Udata "@wifi.id';"]];
       :set $iUrl [$urlEncoder ("https://welcome2.wifi.id/authnew/login/$Url@wifi.id")];
       :if ($accType = "voucher") do={
        :if ($Uid = "@violet") do={
         :set $payloads [$urlEncoder ("username=$user&password=$passwd")];
        } else={
         :set $payloads [$urlEncoder ("username=$user@spin2&password=$passwd")];
        }
       }
       :if ($accType = "smartbisnis") do={
        :set $payloads [$urlEncoder ("username=$user@com.smartbisnis&password=$passwd")];
       }
       :if ($accType = "kampus") do={
        :set $payloads [$urlEncoder ("username=$user.vmgmt@wms.00000000.000&password=$passwd")];
        :if ($Uid = "@ut.ac.id") do={
         :set $payloads [$urlEncoder ("username=$user@com.ut&password=$passwd")];
        }
        :if ($Uid = "@unej") do={
         :set $payloads [$urlEncoder ("username=$kUser@com.unej&password=$passwd")];
        }
        :if ($Uid = "@umaha") do={
         :set $payloads [$urlEncoder ("username=$kUser@com.umaha&password=$passwd")];
        }
        :if ($Uid = "@trisakti") do={
         :set $payloads [$urlEncoder ("username=$kUser@com.trisakti&password=$passwd")];
        }
        :if ($Uid = "@itdel") do={
         :set $payloads [$urlEncoder ("username=$kUser@com.itdel&password=$passwd")];
        }
        :if ($Uid = "@polije") do={
         :set $payloads [$urlEncoder ("username=$kUser@com.polije&password=$passwd")];
        }
        :if ($Uid = "@unsiq") do={
         :set $payloads [$urlEncoder ("username=$kUser@com.unsiq&password=$passwd")];
        }
       }
      }
     } on-error={}
     :delay 5;
     :if ([/ping 8.8.8.8 interval=1 count=1] = 1) do={
      :log warning "WMS: Login success";
     } else={
      :do {
       :set $result ([/tool fetch http-method=post http-header-field=("Referer: $portalUrl, User-Agent: Mozilla/5.0") http-data=$payloads host="welcome2.wifi.id" url=$iUrl output=user as-value]->"data");
       :delay 5;
       :if ([/ping 8.8.8.8 interval=1 count=1] = 1) do={
        :log warning "WMS: Login success";
       } else={:log warning "WMS: Login failed !"}
      } on-error={
       :log warning "WMS: Login failed !";
      }
     }
    }
   } else={:log warning "WMS: Internet connected"}
   /ip firewall nat enable [find where out-interface=$iFace]
  }
 } else={:log warning "WMS: WLAN disconnected !"}
}
