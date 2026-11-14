#!/system/bin/sh
ui_print "============================================"
ui_print "   Performance_AllProject v2.0 PRO"
ui_print "   Developer: AllProject"
ui_print "============================================"
ui_print "[*] Mendeteksi arsitektur SoC & Storage..."

SOC_INFO=$(getprop ro.board.platform)
ui_print "[*] Platform terdeteksi: ${SOC_INFO:-MediaTek/Android}"

# Bersihkan format baris Windows (CRLF -> LF) agar anti-error saat diekstrak
for shfile in "$MODPATH"/*.sh; do
    [ -f "$shfile" ] && sed -i 's/\r$//' "$shfile" 2>/dev/null
done

ui_print "[*] Menyiapkan konfigurasi default & daftar game..."
if [ ! -f "$MODPATH/config.conf" ]; then
    cat << 'EOF' > "$MODPATH/config.conf"
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

if [ ! -f "$MODPATH/games.list" ]; then
    cat << 'EOF' > "$MODPATH/games.list"
com.mobile.legends
com.dts.freefireth
com.dts.freefiremax
com.tencent.ig
com.pubg.imjp
com.pubg.krmobile
com.HoYoverse.GenshinImpact
com.activision.callofduty.shooter
EOF
fi

ui_print "[*] Mengatur hak akses eksekusi skrip..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/daemon.sh" 0 0 0755
set_perm "$MODPATH/apply_tweaks.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

ui_print "[*] Instalasi selesai! Reboot perangkat untuk mengaktifkan."
ui_print "============================================"