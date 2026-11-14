#!/system/bin/sh
MODDIR=${0%/*}

pkill -f "$MODDIR/daemon.sh" 2>/dev/null
settings delete system min_refresh_rate 2>/dev/null
settings delete system peak_refresh_rate 2>/dev/null
rm -f /data/local/tmp/perf_allproject.log