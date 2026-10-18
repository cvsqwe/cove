pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Профили оформления: готовые пресеты и свои снимки текущего вида.
// Профиль = частичные значения разделов appearance / bar / island / windows + обои.
Singleton {
    id: root

    readonly property var sections: ["appearance", "bar", "island", "windows", "terminal"]

    readonly property var presets: ({
        "Уют": {
            icon: "󰅶", desc: I18n.tr("Мягкие скругления, неспешные упругие анимации"),
            appearance: { palette: "wallpaper", radius: 20, frameRadius: 26, barHeight: 40, springiness: 0.42, animSpeed: 0.85, tint: 1.2, saturation: 0.9 },
            windows: { rounding: 18, gapsIn: 8, gapsOut: 16, blur: true, shadow: true, glow: false, borderSize: 2 }
        },
        "Неон": {
            icon: "󱩖", desc: I18n.tr("Яркий акцент, свечение окон, пружинистый остров"),
            appearance: { palette: "custom", customAccent: "#ff4fd8", saturation: 1.4, tint: 1.4, springiness: 0.22, light: false },
            windows: { glow: true, borderSize: 3, borderGradient: true, rounding: 14, dimInactive: true, dimStrength: 0.2 }
        },
        "Минимал": {
            icon: "󰝤", desc: I18n.tr("Плоско, тонко, быстро — ничего лишнего"),
            appearance: { palette: "catppuccin", radius: 6, frameRadius: 0, frame: false, barHeight: 30, animSpeed: 1.5, springiness: 0.6, tint: 0.6 },
            bar: { visualizerStrip: false, workspaceStyle: "dots" },
            windows: { rounding: 6, gapsIn: 3, gapsOut: 6, blur: false, shadow: false, glow: false, borderSize: 1 }
        },
        "День": {
            icon: "󰖙", desc: I18n.tr("Светлая тема, цвета из обоев"),
            appearance: { light: true, palette: "wallpaper", saturation: 1.0, tint: 0.8 }
        },
        "Ночь": {
            icon: "󰖔", desc: I18n.tr("Тёмная тема, приглушённые цвета"),
            appearance: { light: false, palette: "wallpaper", saturation: 0.8, tint: 1.0 }
        },
        "Игровой": {
            icon: "󰊴", desc: I18n.tr("Без анимаций и эффектов — максимум кадров"),
            appearance: { animations: false },
            windows: { blur: false, shadow: false, glow: false, dimInactive: false }
        }
    })

    function snapshot(): var {
        const p = { icon: "󰏘", desc: I18n.tr("Свой профиль"), wallpaper: Store.wallpaper };
        for (const s of sections) {
            const src = Settings[s], out = {};
            for (const k of Object.keys(src)) {
                const v = src[k];
                if (typeof v !== "function" && k !== "objectName" && !k.endsWith("Changed")) out[k] = JSON.parse(JSON.stringify(v));
            }
            p[s] = out;
        }
        return p;
    }

    function save(name: string): void {
        if (!name) return;
        const all = Settings.copy(Settings.profiles ?? {});
        all[name] = snapshot();
        Settings.profiles = all;
    }

    function remove(name: string): void {
        const all = Settings.copy(Settings.profiles ?? {});
        delete all[name];
        Settings.profiles = all;
    }

    function apply(p): void {
        if (!p) return;
        for (const s of sections) {
            if (!p[s]) continue;
            for (const k of Object.keys(p[s])) {
                if (k in Settings[s]) Settings[s][k] = p[s][k];
            }
        }
        if (p.wallpaper) Wallpapers.set(p.wallpaper);
        Sounds.play("unlock");
    }

    // ---- профиль одним файлом (.cove.json): настройки + обои внутри, чтобы перенести на другой компьютер ----
    function exportProfile(name: string): void {
        // имя сохранённого профиля — он; иначе текущий вид под этим именем
        const p = (name && (presets[name] ?? (Settings.profiles ?? {})[name])) || snapshot();
        exporter.payload = JSON.stringify(Object.assign({ cove: 1, name: name || I18n.tr("Мой стиль") }, p));
        exporter.running = true;
    }
    Process {
        id: exporter
        property string payload: ""
        command: ["sh", "-c", 'exec </dev/null
            out=$(zenity --file-selection --save --confirm-overwrite --title="$2" --filename="$HOME/$3.cove.json" 2>/dev/null) || exit 0
            python3 - "$1" "$out" <<"PY"
import base64, json, os, sys
p = json.loads(sys.argv[1])
w = p.get("wallpaper") or ""
if w and os.path.isfile(w) and os.path.getsize(w) < 60_000_000:
    p["wallpaperFile"] = os.path.basename(w)
    p["wallpaperData"] = base64.b64encode(open(w, "rb").read()).decode()
json.dump(p, open(sys.argv[2], "w"), ensure_ascii=False)
PY
            notify-send -a Cove -i cove "$4" "$out"', "_", payload, I18n.tr("Сохранить профиль"), I18n.tr("Профиль Cove"), I18n.tr("Профиль сохранён")]
    }

    function importProfile(): void { importer.running = true; }
    Process {
        id: importer
        command: ["sh", "-c", 'exec </dev/null
            f=$(zenity --file-selection --title="$1" --file-filter="Cove (*.cove.json) | *.cove.json *.json" 2>/dev/null) || exit 0
            python3 - "$f" <<"PY"
import base64, json, os, sys
p = json.load(open(sys.argv[1]))
data = p.pop("wallpaperData", None)
if data:
    d = os.path.expanduser("~/Wallpapers/Imported")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, p.pop("wallpaperFile", "wallpaper.png"))
    open(path, "wb").write(base64.b64decode(data))
    p["wallpaper"] = path
print(json.dumps(p, ensure_ascii=False))
PY', "_", I18n.tr("Открыть профиль")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const p = JSON.parse(text);
                    if (!p.cove) throw "not a cove profile";
                    const all = Settings.copy(Settings.profiles ?? {});
                    let name = p.name || I18n.tr("Импорт");
                    while (all[name] || root.presets[name]) name += " ²";
                    delete p.cove; delete p.name;
                    all[name] = p;
                    Settings.profiles = all;
                    Wallpapers.refresh();
                    Quickshell.execDetached(["notify-send", "-a", "Cove", "-i", "cove", I18n.tr("Профиль добавлен"), name]);
                } catch (e) {
                    Quickshell.execDetached(["notify-send", "-a", "Cove", "-i", "dialog-error", I18n.tr("Не получилось открыть профиль"), String(e)]);
                }
            }
        }
    }

    IpcHandler {
        target: "profiles"
        function list(): string { return [...Object.keys(root.presets), ...Object.keys(Settings.profiles ?? {})].join("\n"); }
        function apply(name: string): void { root.applyNamed(name); }
        function exportFile(name: string): void { root.exportProfile(name); }
        function importFile(): void { root.importProfile(); }
    }

    function applyNamed(name: string): void {
        apply(presets[name] ?? (Settings.profiles ?? {})[name]);
    }
}
