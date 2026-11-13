#!/system/bin/sh
MODDIR=${0%/*}
LOGFILE="/data/local/tmp/perf_allproject.log"

echo "[$(date)] === Performance_AllProject v2.0 Booting ===" > $LOGFILE

# ==========================================
# 1. CPU GOVERNOR & PERFORMANCE PROFILE
# ==========================================
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > "$cpu" 2>/dev/null
done

# ==========================================
# 2. MEDIATEK HELIO G99 PPM & CORE BOOST
# ==========================================
if [ -f /proc/ppm/policy_status ]; then
    echo "1" > /proc/ppm/policy_status 2>/dev/null
fi

# ==========================================
# 3. GPU MALI HIGH-SPEED & POWER POLICY
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
# 6. RAM & LMK (LOW MEMORY KILLER) OPTIMIZATION
# ==========================================
sysctl -w vm.swappiness=60 2>/dev/null
sysctl -w vm.vfs_cache_pressure=100 2>/dev/null
sysctl -w vm.dirty_background_ratio=5 2>/dev/null
sysctl -w vm.dirty_ratio=10 2>/dev/null

# ==========================================
# 7. GAME TURBO PROCESS PRIORITY
# ==========================================
if [ -d /dev/stune/foreground ]; then
    echo 0 > /dev/stune/foreground/schedtune.prefer_idle
    echo 1 > /dev/stune/foreground/schedtune.boost
fi

# ==========================================
# 8. REFRESH RATE / FPS UNLOCKER
# ==========================================
if [ -d /sys/class/drm/card0-DSI-1 ]; then
    echo 1 > /sys/class/drm/card0-DSI-1/max_refresh_rate 2>/dev/null
fi
setprop debug.sf.high_refresh_rate_override 1

# ==========================================
# 9. I/O SCHEDULER & READAHEAD OPTIMIZER
# ==========================================
for queue in /sys/block/*/queue; do
    if [ -f "$queue/scheduler" ]; then
        echo "bfq" > "$queue/scheduler" 2>/dev/null || echo "none" > "$queue/scheduler" 2>/dev/null
    fi
    if [ -f "$queue/read_ahead_kb" ]; then
        echo 2048 > "$queue/read_ahead_kb"
    fi
done

echo "[$(date)] === Core Initialization Complete ===" >> $LOGFILE

# Jalankan Background Daemon untuk Auto-Game Detection
if [ -f "$MODDIR/daemon.sh" ]; then
    nohup sh "$MODDIR/daemon.sh" > /dev/null 2>&1 &
fi

# ==========================================
# EXTREME BATTERY SAVER MODE
# ==========================================
enable_battery_saver() {
    # 1. Pindahkan semua CPU ke governor powersave
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "powersave" > "$cpu" 2>/dev/null
    done

    # 2. Batasi MediaTek PPM agar memprioritaskan core kecil (efisiensi daya)
    if [ -f /proc/ppm/policy_status ]; then
        echo "0" > /proc/ppm/policy_status 2>/dev/null
    fi

    # 3. Matikan GPU boost / turunkan ke frekuensi minimal
    if [ -f /sys/class/mali_boost/mali_high_speed ]; then
        echo "0" > /sys/class/mali_boost/mali_high_speed 2>/dev/null
    fi

    # 4. Agresifkan LMK dan Swappiness untuk hemat memori
    sysctl -w vm.swappiness=20 2>/dev/null
    sysctl -w vm.vfs_cache_pressure=200 2>/dev/null

    echo "[$(date)] Extreme Battery Saver Activated" >> /data/local/tmp/perf_allproject.log
}

# Memunculkan Toast Notifikasi Android Asli saat Booting Selesai
su -lp 2000 -c "cmd toast show 'Performance_AllProject v2.0 Berhasil Aktif!'" 2>/dev/null

# ==========================================
# REAL-TIME TEMPERATURE PERSISTENT NOTIFICATION
# ==========================================
(
    # Beri jeda 10 detik setelah boot selesai agar sistem stabil
    sleep 10

    while true; do
        # 1. Baca suhu dari sensor termal atau baterai
        RAW_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || cat /sys/class/power_supply/battery/temp 2>/dev/null)
        
        if [ -n "$RAW_TEMP" ]; then
            # Format suhu (jika dalam bentuk ribuan, bagi 1000)
            if [ "$RAW_TEMP" -gt 1000 ]; then
                TEMP_C=$((RAW_TEMP / 1000))
            else
                TEMP_C=$RAW_TEMP
            fi
            
            # 2. Kirim/Perbarui Foreground Notification dengan teks kustom
            su -lp 2000 -c "cmd notification post -S bigtext -t 'Tempratur By AllProject' 1945 'Suhu Perangkat Saat Ini: ${TEMP_C}°C (Real-time Monitor)'" 2>/dev/null
        fi

        # Perbarui setiap 10 detik sekali di latar belakang
        sleep 10
    done
) &