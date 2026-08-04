#!/system/bin/sh

grep -Eq '(swinfo|mtdoops|bootmonitor)\.fingerprint=EvolutionX-17\.' /proc/cmdline 2>/dev/null || exit 0
setprop twrp.evox.time_refreshed 0
setprop twrp.evox.time_source none

rtc_file=/sys/class/rtc/rtc0/since_epoch
[ -r "$rtc_file" ] || exit 0
rtc="$(cat "$rtc_file" 2>/dev/null)"
case "$rtc" in
    ''|*[!0-9]*) exit 0 ;;
esac

ats_file=
for candidate in \
    /data/system/time/ats_2 \
    /data/time/ats_2 \
    /data/vendor/time/ats_2 \
    /data/system/time/ats_1 \
    /data/time/ats_1 \
    /data/vendor/time/ats_1; do
    if [ -r "$candidate" ]; then
        ats_file="$candidate"
        break
    fi
done

if [ -z "$ats_file" ]; then
    for directory in /data/system/time /data/time /data/vendor/time; do
        for candidate in "$directory"/ats_*; do
            if [ -f "$candidate" ] && [ -r "$candidate" ]; then
                ats_file="$candidate"
                break 2
            fi
        done
    done
fi
[ -n "$ats_file" ] || exit 0
setprop twrp.evox.time_source "$ats_file"

offset="$(od -An -tu8 -N8 "$ats_file" 2>/dev/null | tr -d '[:space:]')"
case "$offset" in
    ''|*[!0-9]*) exit 0 ;;
esac

epoch=$((rtc + offset / 1000))
[ "$epoch" -ge 1577836800 ] || exit 0
date -u -s "@$epoch" >/dev/null 2>&1 || exit 0
setprop twrp.evox.time_refreshed 1
