#!/system/bin/sh
MODDIR=${0%/*}
LOGFILE="/data/local/tmp/perf_allproject.log"

# Tunggu sampai sistem Android & SystemUI benar-benar selesai booting (CRITICAL!)
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done
sleep 5

echo "[$(date)] === Performance_AllProject v2.0 Safe Booting ===" > $LOGFILE

# ==========================================
# 1. CPU GOVERNOR (Gunakan schedutil agar SystemUI tidak lag/freeze, tapi boost saat beban berat)
# ==========================================
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    # Cek apakah schedutil tersedia, jika tidak baru pakai performance
    if grep -q "schedutil" "$(dirname "$cpu")/scaling_available_governors" 2>/dev/null; then
        echo "schedutil" > "$cpu" 2>/dev/null
    else
        echo "performance" > "$cpu" 2>/dev/null
    fi
done

# ==========================================
# 2. MEDIATEK HELIO G99 PPM & CORE BOOST
# ==========================================
if [ -f /proc/ppm/policy_status ]; then
    echo "1" > /proc/ppm/policy_status 2>/dev/null
fi

# ==========================================
# 3. GPU MALI HIGH-SPEED
# ==========================================
if [ -f /sys/class/mali_boost/mali_high_speed ]; then
    echo "1" > /sys/class/mali_boost/mali_high_speed 2>/dev/null
fi

# ==========================================
# 4. TOUCH SAMPLING BOOST
# ==========================================
if [ -f /proc/touchpanel/game_switch_enable ]; then
    echo "1" > /proc/touchpanel/game_switch_enable 2>/dev/null
fi

# ==========================================
# 5. TCP NETWORK OPTIMIZER (BBR & BUFFER)
# ==========================================
sysctl -w net.core.rmem_max=1048576 2>/dev/null
sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null

# ==========================================
# 6. RAM & LMK (Aman untuk SystemUI agar tidak ter-kill)
# ==========================================
sysctl -w vm.swappiness=60 2>/dev/null
sysctl -w vm.vfs_cache_pressure=100 2>/dev/null
sysctl -w vm.dirty_background_ratio=10 2>/dev/null
sysctl -w vm.dirty_ratio=20 2>/dev/null

# ==========================================
# 7. GAME TURBO PROCESS PRIORITY (Tanpa mencekik SystemUI)
# ==========================================
if [ -d /dev/stune/top-app ]; then
    echo 1 > /dev/stune/top-app/schedtune.boost 2>/dev/null
    echo 0 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
fi

# ==========================================
# 8. I/O SCHEDULER & READAHEAD OPTIMIZER
# ==========================================
for queue in /sys/block/*/queue; do
    if [ -f "$queue/scheduler" ]; then
        echo "bfq" > "$queue/scheduler" 2>/dev/null || echo "none" > "$queue/scheduler" 2>/dev/null
    fi
    if [ -f "$queue/read_ahead_kb" ]; then
        echo 1024 > "$queue/read_ahead_kb" 2>/dev/null
    fi
done

echo "[$(date)] === Core Initialization Complete ===" >> $LOGFILE

# Jalankan Background Daemon jika ada
if [ -f "$MODDIR/daemon.sh" ]; then
    nohup sh "$MODDIR/daemon.sh" > /dev/null 2>&1 &
fi

# ==========================================
# SINGLE TEMPERATURE NOTIFICATION (Hanya Muncul Sekali Saat Booting)
# ==========================================
(
    # Beri jeda 15 detik setelah boot selesai agar sistem stabil
    sleep 15

    RAW_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || cat /sys/class/power_supply/battery/temp 2>/dev/null)
    
    if [ -n "$RAW_TEMP" ]; then
        if [ "$RAW_TEMP" -gt 1000 ]; then
            TEMP_C=$((RAW_TEMP / 1000))
        else
            TEMP_C=$RAW_TEMP
        fi

        # Kirim notifikasi sekali saja secara senyap
        su -lp 2000 -c "cmd notification post --channel low 'Tempratur By AllProject' 1945 'Suhu Perangkat Saat Boot: ${TEMP_C}°C'" 2>/dev/null
    fi
) &