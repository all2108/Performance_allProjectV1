#!/system/bin/sh
MODDIR=${0%/*}
LOGFILE="/data/local/tmp/perf_allproject.log"

# Tunggu sistem Android & SystemUI benar-benar selesai booting
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done
sleep 5

echo "[$(date)] === Performance_AllProject v2.0 Boot Init ===" > "$LOGFILE"

# Terapkan konfigurasi tersimpan secara aman di background
if [ -f "$MODDIR/apply_tweaks.sh" ]; then
    sh "$MODDIR/apply_tweaks.sh" apply_all &
    echo "[$(date)] Tweaks Engine triggered." >> "$LOGFILE"
fi

# Jalankan Background Auto-Game & Thermal Daemon
. "$MODDIR/config.conf" 2>/dev/null
if [ "${TOGGLE_DAEMON:-1}" = "1" ] && [ -f "$MODDIR/daemon.sh" ]; then
    pkill -f "$MODDIR/daemon.sh" 2>/dev/null
    nohup sh "$MODDIR/daemon.sh" > /dev/null 2>&1 &
    echo "[$(date)] Background Daemon started." >> "$LOGFILE"
fi