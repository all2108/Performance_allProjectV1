#!/system/bin/sh
MODDIR=${0%/*}
CONF_FILE="$MODDIR/config.conf"
LOGFILE="/data/local/tmp/perf_allproject.log"

if [ ! -f "$CONF_FILE" ]; then
    cat << 'EOF' > "$CONF_FILE"
PROFILE=performance
TOGGLE_CPU=1
TOGGLE_GPU=1
TOGGLE_PPM=1
TOGGLE_TOUCH=1
TOGGLE_TCP=1
TOGGLE_RAM=1
TOGGLE_TURBO=1
TOGGLE_FPS=1
TOGGLE_IO=1
TOGGLE_DAEMON=1
EOF
fi

. "$CONF_FILE"

set_config() {
    KEY="$1"
    VAL="$2"
    if grep -q "^${KEY}=" "$CONF_FILE" 2>/dev/null; then
        sed -i "s|^${KEY}=.*|${KEY}=${VAL}|g" "$CONF_FILE"
    else
        echo "${KEY}=${VAL}" >> "$CONF_FILE"
    fi
    . "$CONF_FILE"
}

apply_cpu() {
    MODE="$1"
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
        [ -d "$cpu" ] || continue
        AVAIL=$(cat "$cpu/scaling_available_governors" 2>/dev/null)
        MIN_FREQ=$(cat "$cpu/cpuinfo_min_freq" 2>/dev/null)
        MAX_FREQ=$(cat "$cpu/cpuinfo_max_freq" 2>/dev/null)

        if [ "$MODE" = "performance" ] && [ "$TOGGLE_CPU" = "1" ]; then
            if echo "$AVAIL" | grep -q "performance"; then
                echo "performance" > "$cpu/scaling_governor" 2>/dev/null
            elif echo "$AVAIL" | grep -q "schedutil"; then
                echo "schedutil" > "$cpu/scaling_governor" 2>/dev/null
            fi
            [ -n "$MAX_FREQ" ] && echo "$MAX_FREQ" > "$cpu/scaling_max_freq" 2>/dev/null
            if [ -n "$MAX_FREQ" ] && [ -n "$MIN_FREQ" ]; then
                MID_FREQ=$(( (MAX_FREQ + MIN_FREQ) / 2 ))
                echo "$MID_FREQ" > "$cpu/scaling_min_freq" 2>/dev/null
            fi
        elif [ "$MODE" = "batterysaver" ]; then
            if echo "$AVAIL" | grep -q "powersave"; then
                echo "powersave" > "$cpu/scaling_governor" 2>/dev/null
            elif echo "$AVAIL" | grep -q "schedutil"; then
                echo "schedutil" > "$cpu/scaling_governor" 2>/dev/null
            fi
            [ -n "$MIN_FREQ" ] && echo "$MIN_FREQ" > "$cpu/scaling_min_freq" 2>/dev/null
            if [ -n "$MAX_FREQ" ]; then
                CAP_FREQ=$(( (MAX_FREQ * 65) / 100 ))
                echo "$CAP_FREQ" > "$cpu/scaling_max_freq" 2>/dev/null
            fi
        else
            if echo "$AVAIL" | grep -q "schedutil"; then
                echo "schedutil" > "$cpu/scaling_governor" 2>/dev/null
            fi
            [ -n "$MIN_FREQ" ] && echo "$MIN_FREQ" > "$cpu/scaling_min_freq" 2>/dev/null
            [ -n "$MAX_FREQ" ] && echo "$MAX_FREQ" > "$cpu/scaling_max_freq" 2>/dev/null
        fi
    done
}

apply_gpu() {
    ENABLE="$1"
    if [ -d /sys/module/ged/parameters ]; then
        echo "$ENABLE" > /sys/module/ged/parameters/gx_game_mode 2>/dev/null
        echo "$ENABLE" > /sys/module/ged/parameters/gx_boost_on 2>/dev/null
        echo "$ENABLE" > /sys/module/ged/parameters/gx_3D_benchmark_on 2>/dev/null
        echo "$ENABLE" > /sys/module/ged/parameters/gpu_dvfs_enable 2>/dev/null
    fi
    if [ -f /sys/class/mali_boost/mali_high_speed ]; then
        echo "$ENABLE" > /sys/class/mali_boost/mali_high_speed 2>/dev/null
    fi
    for gpol in /sys/devices/platform/*.mali/power_policy /sys/class/misc/mali0/device/power_policy; do
        if [ -f "$gpol" ]; then
            if [ "$ENABLE" = "1" ]; then
                echo "always_on" > "$gpol" 2>/dev/null
            else
                echo "coarse_demand" > "$gpol" 2>/dev/null
            fi
        fi
    done
}

apply_ppm() {
    UNLOCK="$1"
    # Aman: Hanya mengatur PWR_THRO, FORCE_LIMIT & SYS_BOOST (THERMAL & DLPT tetap aktif untuk keamanan hardware)
    if [ -f /proc/ppm/policy_status ]; then
        while IFS= read -r line; do
            IDX=$(echo "$line" | sed -n 's/^\[\([0-9]*\)\].*/\1/p')
            [ -z "$IDX" ] && continue
            case "$line" in
                *PWR_THRO*|*FORCE_LIMIT*)
                    if [ "$UNLOCK" = "1" ]; then
                        echo "$IDX 0" > /proc/ppm/policy_status 2>/dev/null
                    else
                        echo "$IDX 1" > /proc/ppm/policy_status 2>/dev/null
                    fi
                    ;;
                *SYS_BOOST*)
                    echo "$IDX $UNLOCK" > /proc/ppm/policy_status 2>/dev/null
                    ;;
            esac
        done < /proc/ppm/policy_status
    fi
}

apply_touch() {
    ENABLE="$1"
    [ -f /proc/touchpanel/game_switch_enable ] && echo "$ENABLE" > /proc/touchpanel/game_switch_enable 2>/dev/null
    [ -f /sys/class/touch/touch_dev/bump_sample_rate ] && echo "$ENABLE" > /sys/class/touch/touch_dev/bump_sample_rate 2>/dev/null
    [ -f /sys/touchpanel/game_mode ] && echo "$ENABLE" > /sys/touchpanel/game_mode 2>/dev/null
}

apply_tcp() {
    ENABLE="$1"
    if [ "$ENABLE" = "1" ]; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
        sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null
        sysctl -w net.ipv4.tcp_low_latency=1 2>/dev/null
        sysctl -w net.core.rmem_max=2097152 2>/dev/null
        sysctl -w net.core.wmem_max=2097152 2>/dev/null
    else
        sysctl -w net.ipv4.tcp_congestion_control=cubic 2>/dev/null
        sysctl -w net.ipv4.tcp_low_latency=0 2>/dev/null
        sysctl -w net.core.rmem_max=212992 2>/dev/null
        sysctl -w net.core.wmem_max=212992 2>/dev/null
    fi
}

apply_ram() {
    MODE="$1"
    if [ "$MODE" = "batterysaver" ]; then
        sysctl -w vm.swappiness=20 2>/dev/null
        sysctl -w vm.vfs_cache_pressure=120 2>/dev/null
        sysctl -w vm.dirty_background_ratio=5 2>/dev/null
        sysctl -w vm.dirty_ratio=15 2>/dev/null
    elif [ "$TOGGLE_RAM" = "1" ]; then
        sysctl -w vm.swappiness=60 2>/dev/null
        sysctl -w vm.vfs_cache_pressure=80 2>/dev/null
        sysctl -w vm.dirty_background_ratio=10 2>/dev/null
        sysctl -w vm.dirty_ratio=25 2>/dev/null
        sysctl -w vm.page-cluster=0 2>/dev/null
    else
        sysctl -w vm.swappiness=100 2>/dev/null
        sysctl -w vm.vfs_cache_pressure=100 2>/dev/null
    fi
}

apply_turbo() {
    ENABLE="$1"
    if [ -d /dev/cpuctl/top-app ]; then
        if [ "$ENABLE" = "1" ]; then
            echo 20 > /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null
            echo 1 > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null
            echo 10 > /dev/cpuctl/foreground/cpu.uclamp.min 2>/dev/null
        else
            echo 0 > /dev/cpuctl/top-app/cpu.uclamp.min 2>/dev/null
            echo 0 > /dev/cpuctl/top-app/cpu.uclamp.latency_sensitive 2>/dev/null
            echo 0 > /dev/cpuctl/foreground/cpu.uclamp.min 2>/dev/null
        fi
    fi
    if [ -d /dev/stune/top-app ]; then
        echo "$ENABLE" > /dev/stune/top-app/schedtune.boost 2>/dev/null
        echo 0 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
    fi
    if [ -d /dev/stune/foreground ]; then
        echo "$ENABLE" > /dev/stune/foreground/schedtune.boost 2>/dev/null
    fi
}

apply_fps() {
    ENABLE="$1"
    if [ "$ENABLE" = "1" ]; then
        setprop debug.sf.high_refresh_rate_override 1 2>/dev/null
        setprop debug.sf.latch_unsignaled 1 2>/dev/null
        MAX_HZ=$(dumpsys display 2>/dev/null | grep -oE 'fps=[0-9]+' | cut -d= -f2 | sort -nr | head -n1)
        [ -z "$MAX_HZ" ] && MAX_HZ="120"
        settings put system peak_refresh_rate "${MAX_HZ}.0" 2>/dev/null
        settings put system min_refresh_rate "${MAX_HZ}.0" 2>/dev/null
    else
        setprop debug.sf.high_refresh_rate_override 0 2>/dev/null
        settings delete system min_refresh_rate 2>/dev/null
    fi
}

apply_io() {
    ENABLE="$1"
    for blk in /sys/block/sda /sys/block/mmcblk0 /sys/block/dm-0; do
        [ -d "$blk/queue" ] || continue
        if [ "$ENABLE" = "1" ]; then
            AVAIL_IO=$(cat "$blk/queue/scheduler" 2>/dev/null)
            for s in bfq mq-deadline kyber none; do
                if echo "$AVAIL_IO" | grep -q "$s"; then
                    echo "$s" > "$blk/queue/scheduler" 2>/dev/null
                    break
                fi
            done
            echo 2048 > "$blk/queue/read_ahead_kb" 2>/dev/null
            echo 0 > "$blk/queue/iostats" 2>/dev/null
        else
            echo 128 > "$blk/queue/read_ahead_kb" 2>/dev/null
            echo 1 > "$blk/queue/iostats" 2>/dev/null
        fi
    done
}

apply_profile() {
    TARGET_PROFILE="$1"
    [ -z "$TARGET_PROFILE" ] && TARGET_PROFILE="$PROFILE"

    if [ "$TARGET_PROFILE" = "batterysaver" ]; then
        apply_cpu "batterysaver"
        apply_gpu "0"
        apply_ppm "0"
        apply_touch "0"
        apply_ram "batterysaver"
        apply_turbo "0"
        apply_fps "0"
        dumpsys deviceidle force-idle 2>/dev/null
    elif [ "$TARGET_PROFILE" = "balanced" ]; then
        apply_cpu "balanced"
        apply_gpu "0"
        apply_ppm "0"
        apply_touch "$TOGGLE_TOUCH"
        apply_tcp "$TOGGLE_TCP"
        apply_ram "balanced"
        apply_turbo "0"
        apply_fps "$TOGGLE_FPS"
        apply_io "$TOGGLE_IO"
    else
        apply_cpu "performance"
        apply_gpu "$TOGGLE_GPU"
        apply_ppm "$TOGGLE_PPM"
        apply_touch "$TOGGLE_TOUCH"
        apply_tcp "$TOGGLE_TCP"
        apply_ram "performance"
        apply_turbo "$TOGGLE_TURBO"
        apply_fps "$TOGGLE_FPS"
        apply_io "$TOGGLE_IO"
    fi
}

case "$1" in
    apply_all)
        apply_profile "$PROFILE"
        ;;
    set_profile)
        set_config "PROFILE" "$2"
        apply_profile "$2"
        echo "[$(date '+%H:%M:%S')] Profile set to $2" >> "$LOGFILE"
        ;;
    temp_profile)
        apply_profile "$2"
        ;;
    set_toggle)
        KEY="$2"
        VAL="$3"
        set_config "$KEY" "$VAL"
        case "$KEY" in
            TOGGLE_CPU) apply_cpu "$PROFILE" ;;
            TOGGLE_GPU) apply_gpu "$VAL" ;;
            TOGGLE_PPM) apply_ppm "$VAL" ;;
            TOGGLE_TOUCH) apply_touch "$VAL" ;;
            TOGGLE_TCP) apply_tcp "$VAL" ;;
            TOGGLE_RAM) apply_ram "$PROFILE" ;;
            TOGGLE_TURBO) apply_turbo "$VAL" ;;
            TOGGLE_FPS) apply_fps "$VAL" ;;
            TOGGLE_IO) apply_io "$VAL" ;;
            TOGGLE_DAEMON)
                if [ "$VAL" = "1" ]; then
                    pkill -f "$MODDIR/daemon.sh" 2>/dev/null
                    nohup sh "$MODDIR/daemon.sh" > /dev/null 2>&1 &
                else
                    pkill -f "$MODDIR/daemon.sh" 2>/dev/null
                fi
                ;;
        esac
        echo "[$(date '+%H:%M:%S')] Toggle $KEY -> $VAL" >> "$LOGFILE"
        ;;
    clean_ram)
        BEFORE_KB=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
        am kill-all 2>/dev/null
        AFTER_KB=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        FREED_MB=$(( (AFTER_KB - BEFORE_KB) / 1024 ))
        [ "$FREED_MB" -lt 0 ] && FREED_MB=0
        echo "RAM dibersihkan! (+${FREED_MB} MB tersedia)"
        ;;
esac