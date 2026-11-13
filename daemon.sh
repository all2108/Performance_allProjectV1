#!/system/bin/sh
# Performance_AllProject Auto-Game Detection Daemon

LOGFILE="/data/local/tmp/perf_allproject.log"

# Daftar package game yang otomatis dideteksi (bisa ditambah sesuai kebutuhan)
GAME_PACKAGES="com.mobile.legends com.dts.freefireth com.tencent.ig com.pubg.imjp com.HoYoverse.GenshinImpact"

while true; do
    # Ambil fokus aplikasi aktif saat ini
    CURRENT_FOCUS=$(dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp' 2>/dev/null)
    
    IS_GAME=0
    for pkg in $GAME_PACKAGES; do
        case "$CURRENT_FOCUS" in
            *"$pkg"*)
                IS_GAME=1
                break
                ;;
        esac
    done

    if [ "$IS_GAME" -eq 1 ]; then
        # Tindakan saat game dibuka: Maksimalkan schedtune & core boost
        if [ -d /dev/stune/foreground ]; then
            echo 1 > /dev/stune/foreground/schedtune.boost 2>/dev/null
        fi
    else
        # Kembalikan ke mode normal saat keluar game
        if [ -d /dev/stune/foreground ]; then
            echo 0 > /dev/stune/foreground/schedtune.boost 2>/dev/null
        fi
    fi

    sleep 5
done