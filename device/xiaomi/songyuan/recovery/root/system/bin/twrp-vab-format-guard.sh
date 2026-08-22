#!/system/bin/sh

LOG=/tmp/recovery.log
force_format=0

if [ "${1:-}" = "--force" ]; then
    force_format=1
fi

case "$(getprop ro.virtual_ab.enabled 2>/dev/null)" in
    true|1) ;;
    *)
        echo "I:Format Data guard: Virtual A/B is disabled; allowing format." >> "$LOG"
        exit 0
        ;;
esac

if [ ! -x /system/bin/bootctl ]; then
    merge_status=unknown
    merge_rc=127
elif [ -x /system/bin/timeout ]; then
    merge_status=$(/system/bin/timeout 4 /system/bin/bootctl get-snapshot-merge-status 2>>"$LOG")
    merge_rc=$?
else
    merge_status=$(/system/bin/bootctl get-snapshot-merge-status 2>>"$LOG")
    merge_rc=$?
fi

if [ "$merge_rc" != 0 ]; then
    merge_status=unknown
fi

case "$merge_status" in
    none)
        echo "I:Format Data guard: snapshot state is none; allowing format." >> "$LOG"
        exit 0
        ;;
    merging)
        echo "E:Format Data guard: snapshot state is merging; force format is forbidden." >> "$LOG"
        exit 2
        ;;
    snapshotted|cancelled|unknown)
        if [ "$force_format" = 1 ]; then
            echo "W:Format Data guard: snapshot state is $merge_status; allowing confirmed custom-ROM force format." >> "$LOG"
            exit 0
        fi
        echo "E:Format Data guard: snapshot state is $merge_status; confirmation is required." >> "$LOG"
        exit 1
        ;;
    *)
        if [ "$force_format" = 1 ]; then
            echo "W:Format Data guard: unrecognized snapshot state '$merge_status'; allowing confirmed force format." >> "$LOG"
            exit 0
        fi
        echo "E:Format Data guard: unrecognized snapshot state '$merge_status'; treating it as unknown." >> "$LOG"
        exit 1
        ;;
esac
