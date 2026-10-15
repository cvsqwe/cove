pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Профили оформления: готовые пресеты и свои снимки текущего вида.
// Профиль = частичные значения разделов appearance / bar / island / windows + обои.
Singleton {
    id: root

    readonly property var sections: ["appearance", "bar", "island", "windows"]

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

    function applyNamed(name: string): void {
        apply(presets[name] ?? (Settings.profiles ?? {})[name]);
    }
}
