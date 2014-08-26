#!/system/bin/sh
# portions from franciscofranco, ak, boype & osm0sis + Franco's Dev Team

# custom busybox installation shortcut
bb=/sbin/bb/busybox;

# ensure SuperSU daemonsu/Superuser su_daemon service is running
if [ -e /system/xbin/daemonsu ]; then
  /system/xbin/daemonsu --auto-daemon&
elif [ ! -e /init.superuser.rc ]; then
  /system/xbin/su --daemon&
fi;

# create and set permissions for /system/etc/init.d if it doesn't already exist
$bb mount -o rw,remount /system;
if [ ! -e /system/etc/init.d ]; then
  mkdir /system/etc/init.d;
  chown -R root.root /system/etc/init.d;
  chmod -R 755 /system/etc/init.d;
fi;

# disable sysctl.conf to prevent ROM interference with tunables
$bb [ -e /system/etc/sysctl.conf ] && $bb mv -f /system/etc/sysctl.conf /system/etc/sysctl.conf.dvbak;

# disable the PowerHAL since there is now a kernel-side touch boost implemented
$bb [ -e /system/lib/hw/power.tuna.so.dvbak ] || $bb cp /system/lib/hw/power.tuna.so /system/lib/hw/power.tuna.so.dvbak;
$bb [ -e /system/lib/hw/power.tuna.so ] && $bb rm -f /system/lib/hw/power.tuna.so;

# backup and replace Host AP Daemon for working Wi-Fi tether on 3.4 kernel Wi-Fi drivers
$bb [ -e /system/bin/hostapd.dvbak ] || $bb cp /system/bin/hostapd /system/bin/hostapd.dvbak;
$bb cp -f /sbin/hostapd /system/bin/;
chown root.shell /system/bin/hostapd;
chmod 755 /system/bin/hostapd;

# backup and replace Media Codec Profiles if on SR builds, restore if not, and push init.d script to revert for other kernels
case `uname -r` in
  *DirtyV-SR)
    $bb [ -e /system/etc/media_profiles.xml.dvbak ] || $bb cp /system/etc/media_profiles.xml /system/etc/media_profiles.xml.dvbak;
    $bb cp -f /sbin/media_profiles.xml /system/etc/;;
  *)
    $bb [ -e /system/etc/media_profiles.xml.dvbak ] && $bb mv -f /system/etc/media_profiles.xml.dvbak /system/etc/media_profiles.xml;;
esac;
chmod 644 /system/etc/media_profiles.xml;
$bb cp -f /sbin/dvmediarevert /system/etc/init.d/;
chmod 755 /system/etc/init.d/dvmediarevert;
$bb mount -o ro,remount /system;

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
echo 2500000 > /proc/sys/kernel/sched_wakeup_granularity_ns;
echo 962500 > /proc/sys/kernel/sched_rt_runtime_us;

# adjust cgroup timings and decrease max realtime cpu runtime of background tasks
echo 962500 > /dev/cpuctl/cpu.rt_runtime_us;
echo 91 > /dev/cpuctl/apps/bg_non_interactive/cpu.shares;
echo 400000 > /dev/cpuctl/apps/bg_non_interactive/cpu.rt_runtime_us;

# more rational defaults for KSM
echo 256 > /sys/kernel/mm/ksm/pages_to_scan;
echo 1500 > /sys/kernel/mm/ksm/sleep_millisecs;

# initialize cgroup timer_slack for background tasks
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

# disable swappiness by default
echo 0 > /proc/sys/vm/swappiness;

# general queue tweaks
for i in /sys/block/*/queue; do
  echo 512 > $i/nr_requests;
  echo 512 > $i/read_ahead_kb;
  echo 2 > $i/rq_affinity;
  echo 0 > $i/nomerges;
  echo 0 > $i/add_random;
  echo 0 > $i/rotational;
done;

# adjust f2fs partition RAM thresholds to favor userdata
if [ -e /sys/fs/f2fs ]; then
  echo 5 > /sys/fs/f2fs/mmcblk0p10/ram_thresh;
  echo 5 > /sys/fs/f2fs/mmcblk0p11/ram_thresh;
  echo 25 > /sys/fs/f2fs/mmcblk0p12/ram_thresh;
fi;

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

# workaround for hung boots with nodiratime+noatime or barrier=0+data=writeback on ext4, and with
# inline_data, flush_merge, or active_logs=2 on f2fs for userdata via the fstab on older Android versions
case `getprop ro.fs.data` in
  ext4) $bb mount -o remount,nosuid,nodev,noatime,nodiratime,barrier=0 -t auto /data;;
  f2fs) $bb mount -o remount,nosuid,nodev,noatime,nodiratime,inline_data,flush_merge,active_logs=2 -t auto /data;;
esac;

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
/sbin/uci&

# wait for systemui, move it to parent task group, move ksmd to background task group then enable, and adjust systemui+kswapd priorities
while sleep 1; do
  if [ "$($bb pidof com.android.systemui)" ]; then
    systemui=`$bb pidof com.android.systemui`;
    echo $systemui > /dev/cpuctl/tasks;
    echo `$bb pgrep ksmd` > /dev/cpuctl/apps/bg_non_interactive/tasks;
    echo 1 > /sys/kernel/mm/ksm/run;
    echo -17 > /proc/$systemui/oom_adj;
    $bb renice -18 $systemui;
    $bb renice 5 `$bb pgrep kswapd`;
    exit;
  fi;
done&

# lmk whitelist for common launchers+systemui and increase launcher priority
list="com.android.launcher com.google.android.googlequicksearchbox org.adw.launcher org.adwfreak.launcher net.alamoapps.launcher com.anddoes.launcher com.android.lmt com.chrislacy.actionlauncher.pro com.cyanogenmod.trebuchet com.gau.go.launcherex com.gtp.nextlauncher com.miui.mihome2 com.mobint.hololauncher com.mobint.hololauncher.hd com.mycolorscreen.themer com.qihoo360.launcher com.teslacoilsw.launcher com.tsf.shell org.zeam";
while sleep 60; do
  for class in $list; do
    if [ "$($bb pgrep $class)" ]; then
      for launcher in `$bb pgrep $class`; do
        echo -17 > /proc/$launcher/oom_adj;
        $bb renice -18 $launcher;
      done;
    fi;
  done;
  exit;
done&

