const MOD_PATH = "/data/adb/modules/performance_allproject";
const ENGINE = `${MOD_PATH}/apply_tweaks.sh`;
const CONF_FILE = `${MOD_PATH}/config.conf`;
const GAMES_FILE = `${MOD_PATH}/games.list`;

function execScript(cmd) {
    return new Promise((resolve) => {
        if (window.ksu && typeof window.ksu.exec === "function") {
            const cbName = `ksu_cb_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
            window[cbName] = (errno, stdout, stderr) => {
                delete window[cbName];
                const out = (stdout !== undefined && stdout !== null) ? String(stdout) : "";
                const err = (stderr !== undefined && stderr !== null) ? String(stderr) : "";
                resolve(out.trim() || err.trim());
            };
            try {
                window.ksu.exec(cmd, "{}", cbName);
            } catch (e) {
                try {
                    window.ksu.exec(cmd, cbName);
                } catch (e2) {
                    delete window[cbName];
                    resolve("");
                }
            }
        } else {
            console.log("[SIMULATION CMD]: " + cmd);
            resolve("SIMULATED");
        }
    });
}

function showToast(message) {
    const toast = document.getElementById("toast");
    const toastMsg = document.getElementById("toast-message");
    if (!toast || !toastMsg) return;

    toastMsg.innerText = message;
    toast.classList.add("show");
    setTimeout(() => toast.classList.remove("show"), 2600);
}

function switchTab(tabName) {
    document.querySelectorAll(".tab-content").forEach(tab => tab.classList.remove("active"));
    document.querySelectorAll(".tab-btn").forEach(btn => btn.classList.remove("active"));

    const targetTab = document.getElementById("tab-" + tabName);
    const targetBtn = document.getElementById("tab-" + tabName + "-btn");

    if (targetTab) targetTab.classList.add("active");
    if (targetBtn) targetBtn.classList.add("active");

    if (tabName === "games") loadGameList();
}

async function loadSavedState() {
    const confRaw = await execScript(`cat ${CONF_FILE} 2>/dev/null`);
    if (!confRaw || confRaw === "SIMULATED") return;

    const lines = confRaw.split("\n");
    lines.forEach(line => {
        const [key, val] = line.trim().split("=");
        if (!key || val === undefined) return;

        if (key === "PROFILE") {
            document.querySelectorAll(".mode-card").forEach(c => c.classList.remove("active"));
            const activeCard = document.getElementById("mode-" + val);
            if (activeCard) activeCard.classList.add("active");
        } else if (key.startsWith("TOGGLE_")) {
            const checkbox = document.getElementById("toggle-" + key);
            if (checkbox) checkbox.checked = (val === "1");
        }
    });
}

async function updateTelemetry() {
    const cmd = `
        GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "N/A");
        FREQ=$(cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_cur_freq 2>/dev/null || cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0");
        MHZ=$((FREQ / 1000));
        TEMP=$(cat /sys/class/power_supply/battery/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "350");
        [ "$TEMP" -gt 1000 ] && TEMP=$((TEMP / 1000)) || TEMP=$((TEMP / 10));
        BAT=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo "?");
        RAM_AVAIL=$(awk '/MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null);
        RAM_TOT=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null);
        IO=$(cat /sys/block/sda/queue/scheduler /sys/block/mmcblk0/queue/scheduler 2>/dev/null | head -n1 | grep -o '\\[[^]]*\\]' | tr -d '[]');
        echo "$GOV ($MHZ MHz)|$TEMP°C ($BAT%)|$RAM_AVAIL / $RAM_TOT MB|\${IO:-default}"
    `;

    const res = await execScript(cmd);
    if (!res || res === "SIMULATED") return;

    const parts = res.split("|");
    if (parts.length >= 4) {
        document.getElementById("telemetry-gov").innerText = parts[0];
        document.getElementById("telemetry-temp").innerText = parts[1];
        document.getElementById("telemetry-ram").innerText = parts[2];
        document.getElementById("telemetry-io").innerText = parts[3];
    }
}

async function setMode(mode) {
    document.querySelectorAll(".mode-card").forEach(card => card.classList.remove("active"));
    const targetMode = document.getElementById("mode-" + mode);
    if (targetMode) targetMode.classList.add("active");

    await execScript(`sh ${ENGINE} set_profile ${mode}`);
    appendTermOutput(`Profile switched & saved: ${mode.toUpperCase()}`, "info");
    showToast(`Profil aktif: ${mode.toUpperCase()}`);
    setTimeout(updateTelemetry, 400);
}

async function toggleFeature(key, isChecked) {
    const state = isChecked ? "1" : "0";
    await execScript(`sh ${ENGINE} set_toggle ${key} ${state}`);
    appendTermOutput(`Config updated: ${key}=${state}`, "info");
    showToast(`${key.replace("TOGGLE_", "")}: ${isChecked ? "AKTIF" : "NONAKTIF"}`);
    setTimeout(updateTelemetry, 400);
}

async function cleanRamNow() {
    showToast("Membersihkan cache RAM...");
    const res = await execScript(`sh ${ENGINE} clean_ram`);
    appendTermOutput(res || "RAM Cache Cleared", "info");
    showToast(res || "Cache RAM dibersihkan!");
    setTimeout(updateTelemetry, 400);
}

async function loadGameList() {
    const container = document.getElementById("game-list-container");
    if (!container) return;

    const raw = await execScript(`cat ${GAMES_FILE} 2>/dev/null`);
    const pkgs = raw.split("\n").map(p => p.trim()).filter(p => p && p !== "SIMULATED");

    if (pkgs.length === 0) {
        container.innerHTML = `<div class="term-line info">Belum ada game di whitelist.</div>`;
        return;
    }

    container.innerHTML = pkgs.map(pkg => `
        <div class="game-row">
            <span>${pkg}</span>
            <button class="game-del-btn" onclick="removeGamePackage('${pkg}')">
                <i class="fa-solid fa-trash"></i> Hapus
            </button>
        </div>
    `).join("");
}

async function addGamePackage(event) {
    event.preventDefault();
    const input = document.getElementById("new-game-pkg");
    const pkg = input.value.trim().replace(/[^a-zA-Z0-9._]/g, "");
    if (!pkg) return;

    await execScript(`grep -qxF '${pkg}' ${GAMES_FILE} || echo '${pkg}' >> ${GAMES_FILE}`);
    input.value = "";
    showToast(`Ditambahkan: ${pkg}`);
    loadGameList();
}

async function removeGamePackage(pkg) {
    await execScript(`sed -i '/^${pkg.replace(/\./g, "\\.")}$/d' ${GAMES_FILE}`);
    showToast(`Dihapus: ${pkg}`);
    loadGameList();
}

function appendTermOutput(text, type = "") {
    const box = document.getElementById("terminal-output");
    if (!box) return;

    const line = document.createElement("div");
    line.className = "term-line " + type;
    line.innerText = text;
    box.appendChild(line);
    box.scrollTop = box.scrollHeight;
}

async function handleTerminalSubmit(event) {
    event.preventDefault();
    const input = document.getElementById("terminal-input");
    if (!input) return;

    const cmd = input.value.trim();
    if (!cmd) return;

    appendTermOutput("# " + cmd, "cmd");
    input.value = "";
    const result = await execScript(cmd);
    if (result) appendTermOutput(result);
}

async function runQuickCmd(cmd) {
    appendTermOutput("# " + cmd, "cmd");
    const result = await execScript(cmd);
    if (result) appendTermOutput(result);
}

function clearTerminal() {
    const box = document.getElementById("terminal-output");
    if (box) box.innerHTML = "";
}

document.addEventListener("DOMContentLoaded", async () => {
    await loadSavedState();
    await updateTelemetry();
    setInterval(updateTelemetry, 4000);
});