#!/system/bin/sh
MODDIR=${0%/*}
LOGFILE="/data/local/tmp/perf_allproject.log"
GAMES_FILE="$MODDIR/games.list"
CONF_FILE="$MODDIR/config.conf"

LAST_STATE="NORMAL"
COUNTER=0

get_temp_c() {
    RAW_TEMP=$(cat /sys/class/power_supply/battery/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    if [ -n "$RAW_TEMP" ]; then
        if [ "$RAW_TEMP" -gt 1000 ]; then
            echo $((RAW_TEMP / 1000))
        elif [ "$RAW_TEMP" -gt 100 ]; then
            echo $((RAW_TEMP / 10))
        else
            echo "$RAW_TEMP"
        fi
    else
        echo "35"
    fi
}

while true; do
    . "$CONF_FILE" 2>/dev/null
    [ "${TOGGLE_DAEMON:-1}" != "1" ] && exit 0

    TEMP_C=$(get_temp_c)

    # 1. THERMAL SAFETY GUARD (Turunkan beban otomatis jika suhu >= 46°C)
    if [ "$TEMP_C" -ge 46 ]; then
        if [ "$LAST_STATE" != "THERMAL_GUARD" ]; then
            sh "$MODDIR/apply_tweaks.sh" temp_profile balanced
            LAST_STATE="THERMAL_GUARD"
            echo "[$(date '+%H:%M:%S')] THERMAL GUARD ACTIVE (${TEMP_C}°C) -> Cooldown Balanced" >> "$LOGFILE"
            su -lp 2000 -c "cmd notification post --channel low 'Tempratur By AllProject' 1945 'Peringatan Suhu ${TEMP_C}°C! Mode Cooldown Aktif.'" 2>/dev/null
        fi
    else
        # 2. AUTO-GAME FOREGROUND DETECTION
        TOP_APP=$(dumpsys activity activities 2>/dev/null | grep -E 'mResumedActivity|topResumedActivity' | head -n 1)
        IS_GAME=0

        if [ -f "$GAMES_FILE" ]; then
            while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                case "$TOP_APP" in
                    *"$pkg"*)
                        IS_GAME=1
                        ACTIVE_GAME="$pkg"
                        break
                        ;;
                esac
            done < "$GAMES_FILE"
        fi

        if [ "$IS_GAME" -eq 1 ]; then
            if [ "$LAST_STATE" != "GAME" ]; then
                sh "$MODDIR/apply_tweaks.sh" temp_profile performance
                LAST_STATE="GAME"
                echo "[$(date '+%H:%M:%S')] Auto-Game Boost ON ($ACTIVE_GAME)" >> "$LOGFILE"
                su -lp 2000 -c "cmd notification post --channel low 'Tempratur By AllProject' 1945 'Game Boost Aktif (${TEMP_C}°C) • Max Performance'" 2>/dev/null
            fi
        else
            if [ "$LAST_STATE" != "NORMAL" ]; then
                sh "$MODDIR/apply_tweaks.sh" temp_profile "${PROFILE:-balanced}"
                LAST_STATE="NORMAL"
                echo "[$(date '+%H:%M:%S')] Exited Game -> Restored Profile (${PROFILE:-balanced})" >> "$LOGFILE"
            fi
        fi
    fi

    # 3. LIVE TEMPERATURE NOTIFICATION UPDATE (Setiap ~30 detik)
    COUNTER=$((COUNTER + 1))
    if [ "$COUNTER" -ge 6 ]; then
        COUNTER=0
        CUR_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
        su -lp 2000 -c "cmd notification post --channel low 'Tempratur By AllProject' 1945 'Suhu: ${TEMP_C}°C | Mode: ${LAST_STATE} | Gov: ${CUR_GOV}'" 2>/dev/null
    fi

    sleep 5
done