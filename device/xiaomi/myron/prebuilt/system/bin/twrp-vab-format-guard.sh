#!/system/bin/sh

LOG=/tmp/recovery.log

case "$(getprop ro.virtual_ab.enabled 2>/dev/null)" in
	true|1) ;;
	*)
		echo "I:Format Data guard: Virtual A/B is disabled; allowing format." >> "$LOG"
		exit 0
		;;
esac

if [ ! -x /system/bin/bootctl ]; then
	echo "E:Format Data guard: bootctl is unavailable; refusing unsafe format." >> "$LOG"
	exit 1
fi

if [ -x /system/bin/timeout ]; then
	merge_status=$(/system/bin/timeout 4 /system/bin/bootctl get-snapshot-merge-status 2>>"$LOG")
	merge_rc=$?
else
	merge_status=$(/system/bin/bootctl get-snapshot-merge-status 2>>"$LOG")
	merge_rc=$?
fi

if [ "$merge_rc" = "124" ] || [ "$merge_rc" = "137" ]; then
	echo "W:Format Data guard: boot control query timed out; allowing the explicit format request." >> "$LOG"
	exit 0
fi

case "$merge_status" in
	none)
		echo "I:Format Data guard: snapshot state is none; allowing format." >> "$LOG"
		exit 0
		;;
	snapshotted|merging|cancelled|unknown)
		echo "E:Format Data guard: snapshot state is $merge_status; format cancelled." >> "$LOG"
		exit 1
		;;
	*)
		echo "E:Format Data guard: unable to verify snapshot state ('$merge_status'); format cancelled." >> "$LOG"
		exit 1
		;;
esac
