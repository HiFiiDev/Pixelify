#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}

# This script will be executed in late_start service mode

. $MODDIR/vars.sh
. $MODDIR/utils.sh

sqlite=$MODDIR/addon/sqlite3
chmod 0755 $sqlite

TARGET_LOGGING=1
temp=""

pm_enable() {
    pm enable $1 >/dev/null 2>&1
    log "Enabling $1"
}

log() {
    date=$(date +%y/%m/%d)
    tim=$(date +%H:%M:%S)
    temp="$temp
$date $tim: $@"
}

set_prop() {
    setprop "$1" "$2"
    log "Setting prop $1 to $2"
}

bool_patch() {
    file=$2
    if [ -f $file ]; then
        line=$(grep $1 $2 | grep false | cut -c 16- | cut -d' ' -f1)
        for i in $line; do
            val_false='value="false"'
            val_true='value="true"'
            write="${i} $val_true"
            find="${i} $val_false"
            log "Setting bool $(echo $i | cut -d'"' -f2) to True"
            sed -i -e "s/${find}/${write}/g" $file
        done
    fi
}

bool_patch_false() {
    file=$2
    if [ -f $file ]; then
        line=$(grep $1 $2 | grep false | cut -c 14- | cut -d' ' -f1)
        for i in $line; do
            val_false='value="true"'
            val_true='value="false"'
            write="${i} $val_true"
            find="${i} $val_false"
            log "Setting bool $i to False"
            sed -i -e "s/${find}/${write}/g" $file
        done
    fi
}

string_patch() {
    file=$3
    if [ -f $file ]; then
        str1=$(grep $1 $3 | grep string | cut -c 14- | cut -d'>' -f1)
        for i in $str1; do
            str2=$(grep $i $3 | grep string | cut -c 14- | cut -d'<' -f1)
            add="$i>$2"
            if [ ! "$add" == "$str2" ]; then
                log "Setting string $i to $2"
                sed -i -e "s/${str2}/${add}/g" $file
            fi
        done
    fi
}

long_patch() {
    file=$3
    if [ -f $file ]; then
        lon=$(grep $1 $3 | grep long | cut -c 17- | cut -d'"' -f1)
        for i in $lon; do
            str=$(grep $i $3 | grep long | cut -c 17- | cut -d'"' -f1-2)
            str1=$(grep $i $3 | grep long | cut -c 17- | cut -d'"' -f1-3)
            add="$str\"$2"
            if [ ! "$add" == "$str1" ]; then
                log "Setting string $i to $2"
                sed -i -e "s/${str1}/${add}/g" $file
            fi
        done
    fi
}

bootlooped() {
    echo -n >>$MODDIR/disable
    log "- Bootloop detected"
    #echo "$temp" >> /sdcard/Pixelify/logs.txt
    #logcat -d >> /sdcard/Pixelify/boot_logs.txt
    rip="$(logcat -d)"
    rm -rf $MODDIR/boot_logs.txt
    echo "$rip" >>$MODDIR/boot_logs.txt
    cp -Tf $MODDIR/boot_logs.txt /sdcard/Pixelify/boot_logs.txt
    #echo "$rip" >> /sdcard/Pixelify/boot_logs.txt
    sleep .5
    reboot
}

check() {
    VALUEA="$1"
    VALUEB="$2"
    RESULT=false
    for i in $VALUEA; do
        for j in $VALUEB; do
            [ "$i" == "$j" ] && RESULT=true
        done
    done
    $RESULT
}

mkdir -p /sdcard/Pixelify

log "Service Started"

# Call Screening
cp -Tf $MODDIR/com.google.android.dialer /data/data/com.google.android.dialer/files/phenotype/com.google.android.dialer

# Wellbeing
pm_enable com.google.android.apps.wellbeing/com.google.android.apps.wellbeing.walkingdetection.ui.WalkingDetectionActivity

if [ $(grep CallScreen $MODDIR/var.prop | cut -d'=' -f2) -eq 1 ]; then
    mkdir -p /data/data/com.google.android.dialer/files/phenotype
    cp -Tf $MODDIR/com.google.android.dialer /data/data/com.google.android.dialer/files/phenotype/com.google.android.dialer
    chmod 500 /data/data/com.google.android.dialer/files/phenotype
    am force-stop com.google.android.dialer
fi

if [ $(grep Live $MODDIR/var.prop | cut -d'=' -f2) -eq 1 ]; then
    pm enable -n com.google.pixel.livewallpaper/com.google.pixel.livewallpaper.pokemon.wallpapers.PokemonWallpaper -a android.intent.action.MAIN
fi

pm enable -n com.google.android.settings.intelligence/com.google.android.settings.intelligence.modules.battery.impl.usage.BootBroadcastReceiver -a android.intent.action.MAIN
pm enable -n com.google.android.settings.intelligence/com.google.android.settings.intelligence.modules.battery.impl.usage.DataInjectorReceiver -a android.intent.action.MAIN
pm enable -n com.google.android.settings.intelligence/com.google.android.settings.intelligence.modules.batterywidget.impl.BatteryWidgetBootBroadcastReceiver -a android.intent.action.MAIN
pm enable -n com.google.android.settings.intelligence/com.google.android.settings.intelligence.modules.batterywidget.impl.BatteryWidgetUpdateReceiver -a android.intent.action.MAIN
pm enable -n com.google.android.settings.intelligence/com.google.android.settings.intelligence.modules.battery.impl.usage.PeriodicJobReceiver -a android.intent.action.MAIN
sleep .5
pm enable -n com.google.android.settings.intelligence/com.google.android.settings.intelligence.modules.batterywidget.impl.BatteryAppWidgetProvider -a android.intent.action.MAIN

am force-stop com.google.android.settings.intelligence

#HuskyDG@github's bootloop preventer
MAIN_ZYGOTE_NICENAME=zygote
MAIN_SYSUI_NICENAME=com.android.systemui

CPU_ABI=$(getprop ro.product.cpu.api)
[ "$CPU_ABI" = "arm64-v8a" -o "$CPU_ABI" = "x86_64" ] && MAIN_ZYGOTE_NICENAME=zygote64

# Wait for zygote to start
sleep 5
ZYGOTE_PID1=$(pidof "$MAIN_ZYGOTE_NICENAME")
echo "1z is $ZYGOTE_PID1"

# Wait for SystemUI to start
sleep 10
SYSUI_PID1=$(pidof "$MAIN_SYSUI_NICENAME")
echo "1s is $SYSUI_PID1"

sleep 15
ZYGOTE_PID2=$(pidof "$MAIN_ZYGOTE_NICENAME")
SYSUI_PID2=$(pidof "$MAIN_SYSUI_NICENAME")
echo "2z is $ZYGOTE_PID2"
echo "2s is $SYSUI_PID2"

cp -Tf $MODDIR/com.google.android.dialer /data/data/com.google.android.dialer/files/phenotype/com.google.android.dialer

if check "$ZYGOTE_PID1" "$ZYGOTE_PID2"; then
    echo "No zygote error on step 1, ok!"
else
    echo "Error on zygote step 1 but continue just to make sure..."
fi

if check "$SYSUI_PID1" "$SYSUI_PID2"; then
    echo "No SystemUI error on step 1, ok!"
else
    echo "Error on SystemUI step 1 but continue just to make sure..."
fi

sleep 30
ZYGOTE_PID3=$(pidof "$MAIN_ZYGOTE_NICENAME")
SYSUI_PID3=$(pidof "$MAIN_SYSUI_NICENAME")
echo "3z is $ZYGOTE_PID3"
echo "3s is $SYSUI_PID3"

cp -Tf $MODDIR/com.google.android.dialer /data/data/com.google.android.dialer/files/phenotype/com.google.android.dialer
am force-stop com.google.android.dialer
patch_gboard
am force-stop com.google.android.dialer com.google.android.inputmethod.latin

pref_patch 45353596 1 boolean $PHOTOS_PREF
pref_patch 45363145 1 boolean $PHOTOS_PREF
pref_patch 45357512 1 boolean $PHOTOS_PREF
pref_patch 45361445 1 boolean $PHOTOS_PREF
pref_patch 45357511 1 boolean $PHOTOS_PREF
pref_patch photos.backup.throttled_state 0 boolean $PHOTOS_PREF

if check "$ZYGOTE_PID2" "$ZYGOTE_PID3"; then
    echo "No zygote error on step 2, ok!"
else if [ $(getprop sys.boot_completed) -eq 0 ]; then
    echo "Error on zygote step 2 as well"
    echo "Boot loop detected! Starting rescue script..."
    bootlooped
fi

if check "$SYSUI_PID2" "$SYSUI_PID3"; then
    echo "No SystemUI error on step 2, ok!"
else if [ $(getprop sys.boot_completed) -eq 0 ]; then
    echo "Error on SystemUI step 2 as well"
    echo "Boot loop detected! Starting rescue script..."
    bootlooped
fi

# Set device config
set_device_config

log "Service Finished"
echo "$temp" >>/sdcard/Pixelify/logs.txt
