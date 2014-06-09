#!/system/bin/sh
# portions from franciscofranco, ak, boype & osm0sis + Franco's Dev Team

# custom busybox installation shortcut
bb=/sbin/bb/busybox;

# disable sysctl.conf to prevent ROM interference with tunables
$bb mount -o rw,remount /system;
$bb [ -e /system/etc/sysctl.conf ] && $bb mv -f /system/etc/sysctl.conf /system/etc/sysctl.conf.dvbak;

# disable the PowerHAL since there is now a kernel-side touch boost implemented
$bb [ -e /system/lib/hw/power.tuna.so.dvbak ] || $bb cp /system/lib/hw/power.tuna.so /system/lib/hw/power.tuna.so.dvbak;
$bb [ -e /system/lib/hw/power.tuna.so ] && $bb rm -f /system/lib/hw/power.tuna.so;

# backup and replace Host AP Daemon for working Wi-Fi tether on 3.4 kernel Wi-Fi drivers
$bb [ -e /system/bin/hostapd.dvbak ] || $bb cp /system/bin/hostapd /system/bin/hostapd.dvbak;
$bb cp -f /sbin/hostapd /system/bin/;
chown root.shell /system/bin/hostapd;
chmod 755 /system/bin/hostapd;

# backup and replace Media Codec Profiles if on SR builds, restore if not, and push init.d script for other kernels
case `uname -r` in
  *DirtyV-SR)
    $bb [ -e /system/etc/media_profiles.xml.dvbak ] || $bb cp /system/etc/media_profiles.xml /system/etc/media_profiles.xml.dvbak;
    $bb cp -f /sbin/media_profiles.xml /system/etc/;
    chmod 644 /system/etc/media_profiles.xml;;
  *)
    $bb [ -e /system/etc/media_profiles.xml.dvbak ] && $bb mv -f /system/etc/media_profiles.xml.dvbak /system/etc/media_profiles.xml;
    chmod 644 /system/etc/media_profiles.xml;;
esac;
$bb cp -f /sbin/dvmediarevert /system/etc/init.d/;
chmod 755 /system/etc/init.d/dvmediarevert;

# create and set permissions for /system/etc/init.d if it doesn't already exist
if [ ! -e /system/etc/init.d ]; then
  mkdir /system/etc/init.d;
  chown -R root.root /system/etc/init.d;
  chmod -R 755 /system/etc/init.d;
fi;
$bb mount -o ro,remount /system;

# fix permissions for any included governors (and older underlying ramdisks)
governor=reset;
while sleep 1; do
  current=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`;
  if [ $governor != $current ]; then
    governor=$current;
    for i in /sys/devices/system/cpu/cpufreq/*; do
      chown system:system $i/*;
      chmod 664 $i/*;
    done;
  fi;
done&

# disable debugging
echo 0 > /sys/module/wakelock/parameters/debug_mask;
echo 0 > /sys/module/userwakelock/parameters/debug_mask;
echo 0 > /sys/module/earlysuspend/parameters/debug_mask;
echo 0 > /sys/module/alarm/parameters/debug_mask;
echo 0 > /sys/module/alarm_dev/parameters/debug_mask;
echo 0 > /sys/module/binder/parameters/debug_mask;

# suitable configuration to help reduce network latency
echo 2 > /proc/sys/net/ipv4/tcp_ecn;
echo 1 > /proc/sys/net/ipv4/tcp_sack;
echo 1 > /proc/sys/net/ipv4/tcp_dsack;
echo 1 > /proc/sys/net/ipv4/tcp_low_latency;
echo 1 > /proc/sys/net/ipv4/tcp_timestamps;

# reduce txqueuelen to 0 to switch from a packet queue to a byte one
for i in /sys/class/net/*; do
  echo 0 > $i/tx_queue_len;
done;

# increase sched timings
echo 15000000 > /proc/sys/kernel/sched_latency_ns;
echo 2000000 > /proc/sys/kernel/sched_min_granularity_ns;
echo 3000000 > /proc/sys/kernel/sched_wakeup_granularity_ns;

# adjust background app cgroup priority
echo 91 > /dev/cpuctl/apps/bg_non_interactive/cpu.shares;
echo 400000 > /dev/cpuctl/apps/bg_non_interactive/cpu.rt_runtime_us;

# more rational defaults for KSM
echo 256 > /sys/kernel/mm/ksm/pages_to_scan;
echo 1500 > /sys/kernel/mm/ksm/sleep_millisecs;

# initialize timer_slack
echo 100000000 > /dev/cpuctl/apps/bg_non_interactive/timer_slack.min_slack_ns;

# decrease fs lease time
echo 10 > /proc/sys/fs/lease-break-time;

# tweak for slightly larger kernel entropy pool
echo 128 > /proc/sys/kernel/random/read_wakeup_threshold;
echo 256 > /proc/sys/kernel/random/write_wakeup_threshold;

# disabled ASLR to increase AEM-JIT cache hit rate
echo 0 > /proc/sys/kernel/randomize_va_space;

# double the default minfree kb
echo 2884 > /proc/sys/vm/min_free_kbytes;

# general queue tweaks
for i in /sys/block/*/queue; do
  echo 512 > $i/nr_requests;
  echo 512 > $i/read_ahead_kb;
  echo 2 > $i/rq_affinity;
  echo 0 > $i/nomerges;
  echo 0 > $i/add_random;
  echo 0 > $i/rotational;
done;

# remount sysfs+sdcard with noatime,nodiratime since that's all they accept
$bb mount -o remount,nosuid,nodev,noatime,nodiratime -t auto /;
$bb mount -o remount,nosuid,nodev,noatime,nodiratime -t auto /proc;
$bb mount -o remount,nosuid,nodev,noatime,nodiratime -t auto /sys;
$bb mount -o remount,nosuid,nodev,noatime,nodiratime -t auto /sys/kernel/debug;
$bb mount -o remount,nosuid,nodev,noatime,nodiratime -t auto /mnt/shell/emulated;
for i in /storage/emulated/*; do
  $bb mount -o remount,nosuid,nodev,noatime,nodiratime -t auto $i;
  $bb mount -o remount,nosuid,nodev,noatime,nodiratime -t auto $i/Android/obb;
done;

# workaround for hung boots with nodiratime+noatime or barrier=0+data=writeback
# which occur when used as ext4 mount options for userdata via the tuna fstab
$bb [ `getprop ro.fs.data` == "ext4" ] && $bb mount -o remount,nosuid,nodev,noatime,nodiratime,barrier=0 -t auto /data;

# lmk tweaks for fewer empty background processes
minfree=6144,8192,12288,16384,24576,40960;
lmk=/sys/module/lowmemorykiller/parameters/minfree;
minboot=`cat $lmk`;
while sleep 1; do
  if [ `cat $lmk` != $minboot ]; then
    [ `cat $lmk` != $minfree ] && echo $minfree > $lmk || exit;
  fi;
done&

# set up suspend_trim support
trimhelper=/data/trimhelper;
if [ -s /data/trimhelper ]; then
  $bb sed -i "1s/.*/$($bb date +%s)/" $trimhelper;
  $bb sed -i "4s/.*/0/" $trimhelper;
else
  $bb date +%s > $trimhelper;
  echo 0 >> $trimhelper;
  echo 0 >> $trimhelper;
  echo 0 >> $trimhelper;
fi;

# set up Synapse support
/sbin/uci &

# wait for systemui and adjust some process priorities
while sleep 1; do
  if [ `$bb pidof com.android.systemui` ]; then
    systemui=`$bb pidof com.android.systemui`;
    echo $systemui > /dev/cpuctl/tasks;
    echo -17 > /proc/$systemui/oom_adj;
    $bb renice -18 $systemui;
    $bb renice 5 `$bb pgrep kswapd`;
    exit;
  fi;
done&

# lmk whitelist for common launchers+systemui and increase launcher priority
list="com.android.launcher com.google.android.googlequicksearchbox org.adw.launcher org.adwfreak.launcher net.alamoapps.launcher com.anddoes.launcher com.android.lmt com.chrislacy.actionlauncher.pro com.cyanogenmod.trebuchet com.gau.go.launcherex com.gtp.nextlauncher com.miui.mihome2 com.mobint.hololauncher com.mobint.hololauncher.hd com.mycolorscreen.themer com.qihoo360.launcher com.teslacoilsw.launcher com.tsf.shell org.zeam";
echo 1 > /sys/module/lowmemorykiller/parameters/donotkill_sysproc;
while sleep 60; do
  for class in $list; do
    if [ `$bb pgrep $class | head -n 1` ]; then
      launcher=`$bb pgrep $class`;
      echo "com.android.systemui,$class" > /sys/module/lowmemorykiller/parameters/donotkill_sysproc_names;
      [ -e /sdcard/Synapse/lmk_whitelists/.sys_processes -a -z `cat /sdcard/Synapse/lmk_whitelists/.sys_processes` ] && echo "com.android.systemui\n$class" > /sdcard/Synapse/lmk_whitelists/.sys_processes;
      echo -17 > /proc/$launcher/oom_adj;
      $bb renice -18 $launcher;
    fi;
  done;
  exit;
done&

