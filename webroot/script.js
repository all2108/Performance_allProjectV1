// ==========================================
// KERNELSU EXEC COMMAND BRIDGE
// ==========================================
function execScript(cmd) {
    if (window.ksu && typeof window.ksu.exec === 'function') {
        try {
            return window.ksu.exec(cmd);
        } catch (e) {
            console.error("KernelSU Exec Error:", e);
        }
    }
    console.log("[SIMULATION CMD]: " + cmd);
    return "OK (Simulated)";
}

// ==========================================
// TOAST NOTIFICATION SYSTEM
// ==========================================
function showToast(message) {
    const toast = document.getElementById('toast');
    const toastMsg = document.getElementById('toast-message');
    
    if (!toast || !toastMsg) return;

    toastMsg.innerText = message;
    toast.classList.add('show');
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 2500);
}

// ==========================================
// TAB SWITCHING SYSTEM
// ==========================================
function switchTab(tabName) {
    document.querySelectorAll('.tab-content').forEach(tab => tab.classList.remove('active'));
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));

    const targetTab = document.getElementById('tab-' + tabName);
    const targetBtn = document.getElementById('tab-' + tabName + '-btn');

    if (targetTab) targetTab.classList.add('active');
    if (targetBtn) targetBtn.classList.add('active');
}

// ==========================================
// LIVE TELEMETRY UPDATER
// ==========================================
function updateTelemetry() {
    let govResult = execScript("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor");
    let ioResult = execScript("cat /sys/block/sda/queue/scheduler");

    const govElem = document.getElementById('telemetry-gov');
    const ioElem = document.getElementById('telemetry-io');

    if (govElem && govResult) {
        govElem.innerText = govResult.trim();
    }
    if (ioElem && ioResult) {
        // Ambil teks di dalam kurung siku scheduler aktif
        let activeIo = ioResult.trim();
        ioElem.innerText = activeIo;
    }
}

// ==========================================
// MODE SELECTION SYSTEM
// ==========================================
function setMode(mode) {
    document.querySelectorAll('.mode-card').forEach(card => card.classList.remove('active'));
    const targetMode = document.getElementById('mode-' + mode);
    if (targetMode) targetMode.classList.add('active');

    let cmd = "";
    if (mode === 'performance') {
        cmd = "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $cpu; done;";
    } else if (mode === 'balanced') {
        cmd = "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo schedutil > $cpu; done;";
    } else if (mode === 'batterysaver') {
        cmd = "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > $cpu; done; " +
              "sysctl -w vm.swappiness=20;";
    }
    
    execScript(cmd);
    appendTermOutput("Mode changed to " + mode.toUpperCase(), "info");
    showToast(`Mode diubah ke: ${mode.toUpperCase()}`);
    
    // Refresh telemetry instantly
    setTimeout(updateTelemetry, 500);
}

// ==========================================
// FEATURE TOGGLE SYSTEM
// ==========================================
function toggleFeature(feature, isChecked) {
    let state = isChecked ? "1" : "0";
    let cmd = "";

    if (feature === 'cpu') {
        cmd = isChecked 
            ? "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $cpu; done;" 
            : "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo schedutil > $cpu; done;";
    } else if (feature === 'touch') {
        cmd = `[ -f /proc/touchpanel/game_switch_enable ] && echo ${state} > /proc/touchpanel/game_switch_enable;`;
    } else if (feature === 'gpu') {
        cmd = `[ -f /sys/class/mali_boost/mali_high_speed ] && echo ${state} > /sys/class/mali_boost/mali_high_speed;`;
    } else if (feature === 'tcp') {
        cmd = isChecked ? "sysctl -w net.core.rmem_max=1048576" : "sysctl -w net.core.rmem_max=212992";
    } else if (feature === 'ram') {
        cmd = isChecked 
            ? "sysctl -w vm.swappiness=60; sysctl -w vm.vfs_cache_pressure=100;" 
            : "sysctl -w vm.swappiness=100; sysctl -w vm.vfs_cache_pressure=100;";
    } else if (feature === 'turbo') {
        cmd = isChecked 
            ? "[ -d /dev/stune/foreground ] && echo 1 > /dev/stune/foreground/schedtune.boost;" 
            : "[ -d /dev/stune/foreground ] && echo 0 > /dev/stune/foreground/schedtune.boost;";
    } else if (feature === 'fps') {
        cmd = isChecked 
            ? "setprop debug.sf.high_refresh_rate_override 1;" 
            : "setprop debug.sf.high_refresh_rate_override 0;";
    } else if (feature === 'io') {
        cmd = isChecked 
            ? "for q in /sys/block/*/queue/read_ahead_kb; do echo 2048 > $q; done;" 
            : "for q in /sys/block/*/queue/read_ahead_kb; do echo 128 > $q; done;";
    }

    execScript(cmd);
    appendTermOutput(`Feature [${feature.toUpperCase()}] set to ${isChecked ? 'ON' : 'OFF'}`, "info");
    showToast(`Fitur ${feature.toUpperCase()} ${isChecked ? 'Aktif' : 'Dimatikan'}`);
    
    setTimeout(updateTelemetry, 500);
}

// ==========================================
// TERMINAL SYSTEM
// ==========================================
function appendTermOutput(text, type = "") {
    const box = document.getElementById('terminal-output');
    if (!box) return;

    const line = document.createElement('div');
    line.className = "term-line " + type;
    line.innerText = text;
    box.appendChild(line);
    box.scrollTop = box.scrollHeight;
}

function handleTerminalSubmit(event) {
    event.preventDefault();
    const input = document.getElementById('terminal-input');
    if (!input) return;

    const cmd = input.value.trim();
    if (!cmd) return;

    appendTermOutput("$ " + cmd, "cmd");
    const result = execScript(cmd);
    if (result) appendTermOutput(result);

    input.value = "";
}

function runQuickCmd(cmd) {
    appendTermOutput("$ " + cmd, "cmd");
    const result = execScript(cmd);
    if (result) appendTermOutput(result);
}

function clearTerminal() {
    const box = document.getElementById('terminal-output');
    if (box) box.innerHTML = "";
}

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    updateTelemetry();
    // Auto-refresh telemetry every 5 seconds while Web UI is open
    setInterval(updateTelemetry, 5000);
});