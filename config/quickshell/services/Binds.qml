pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Хоткеи: стандартный набор, редактирование, поиск конфликтов.
// Бинд: { mods: "SUPER SHIFT", key: "R", action: "shell.launcher", arg: "", label: "",
//         enabled: true, locked: false, repeating: false }
Singleton {
    id: root

    readonly property var modOrder: ["SUPER", "CTRL", "ALT", "SHIFT"]

    function b(mods: string, key: string, action: string, arg, extra): var {
        return Object.assign({ mods, key, action, arg: arg ?? "", label: "", enabled: true, locked: false, repeating: false }, extra ?? {});
    }

    function defaults(): var {
        const L = { locked: true }, LR = { locked: true, repeating: true }, R = { repeating: true };
        const list = [
            b("SUPER", "Q", "app.terminal"),
            b("SUPER", "E", "app.files"),
            b("SUPER", "B", "app.browser"),
            b("SUPER", "C", "win.close"),
            b("SUPER", "V", "win.float"),
            b("SUPER", "F", "win.fullscreen"),
            b("SUPER SHIFT", "F", "win.maximize"),
            b("SUPER", "P", "win.pseudo"),
            b("SUPER", "J", "win.split"),
            b("SUPER SHIFT", "P", "win.pin"),

            b("SUPER", "R", "shell.launcher"),
            b("SUPER", "SPACE", "shell.launcher"),
            b("SUPER SHIFT", "V", "shell.clipboard"),
            b("SUPER", "X", "shell.palette"),
            b("SUPER", "N", "shell.control"),
            b("SUPER", "A", "shell.dashboard"),
            b("SUPER", "TAB", "shell.overview"),
            b("SUPER", "W", "shell.wallpaper"),
            b("SUPER", "ESCAPE", "shell.session"),
            b("SUPER", "M", "shell.session"),
            b("SUPER", "L", "shell.lock"),
            b("SUPER", "comma", "shell.settings"),
            b("SUPER", "slash", "shell.cheatsheet"),
            b("SUPER SHIFT", "N", "shell.notes"),
            b("SUPER", "T", "shell.focus"),
            b("SUPER SHIFT", "C", "shell.picker"),
            b("SUPER ALT", "R", "shell.record"),
            b("SUPER ALT SHIFT", "R", "shell.recordRegion"),
            b("", "Print", "shell.shotArea"),
            b("SHIFT", "Print", "shell.shotScreen"),
            b("ALT", "Sys_Req", "shell.shotWindow"),       // Alt+PrtSc приходит как Sys_Req
            b("SUPER SHIFT", "S", "shell.shotArea"),        // для клавиатур без PrtSc
            b("SUPER CTRL", "S", "shell.shotScreen"),
            b("SUPER ALT", "W", "shell.shotWindow"),
            b("SUPER", "Print", "shell.shotScreen"),
            b("SUPER SHIFT", "R", "shell.restart"),
            b("SUPER", "G", "toggle.game")
        ];

        for (const d of ["left", "right", "up", "down"]) {
            list.push(b("SUPER", d, "win.focus", d));
            list.push(b("SUPER SHIFT", d, "win.move", d));
            list.push(b("SUPER CTRL", d, "win.resize", d, R));
        }
        for (let i = 1; i <= 10; i++) {
            const key = String(i % 10);
            list.push(b("SUPER", key, "ws.focus", String(i)));
            list.push(b("SUPER SHIFT", key, "ws.move", String(i)));
        }
        list.push(b("SUPER", "S", "ws.special", "magic"));
        list.push(b("SUPER ALT", "S", "ws.toSpecial", "magic"));
        list.push(b("SUPER", "mouse_down", "ws.next"));
        list.push(b("SUPER", "mouse_up", "ws.prev"));
        list.push(b("SUPER", "mouse:272", "win.drag"));
        list.push(b("SUPER", "mouse:273", "win.resizeMouse"));

        list.push(b("", "XF86AudioRaiseVolume", "media.volUp", "", LR));
        list.push(b("", "XF86AudioLowerVolume", "media.volDown", "", LR));
        list.push(b("", "XF86AudioMute", "media.mute", "", L));
        list.push(b("", "XF86AudioMicMute", "media.micMute", "", L));
        list.push(b("", "XF86MonBrightnessUp", "media.brightUp", "", LR));
        list.push(b("", "XF86MonBrightnessDown", "media.brightDown", "", LR));
        list.push(b("", "XF86AudioPlay", "media.play", "", L));
        list.push(b("", "XF86AudioPause", "media.play", "", L));
        list.push(b("", "XF86AudioNext", "media.next", "", L));
        list.push(b("", "XF86AudioPrev", "media.prev", "", L));
        return list;
    }

    function ensureDefaults(): void {
        if (!Settings.binds || Settings.binds.length === 0) Settings.binds = defaults();
    }

    function normMods(mods: string): string {
        const set = new Set(String(mods ?? "").toUpperCase().split(/[\s+]+/).filter(Boolean));
        return modOrder.filter(m => set.has(m)).join(" ");
    }

    // "SUPER + SHIFT + R"
    function combo(bind): string {
        const m = normMods(bind.mods);
        return m ? m.split(" ").join(" + ") + " + " + bind.key : bind.key;
    }

    // красивое имя клавиши для интерфейса
    function prettyKey(k: string): string {
        const map = {
            "SPACE": I18n.tr("Пробел"), "ESCAPE": "Esc", "TAB": "Tab", "RETURN": "Enter", "Print": "PrtSc",
            "left": "←", "right": "→", "up": "↑", "down": "↓", "comma": ",", "period": ".", "slash": "/",
            "mouse_down": I18n.tr("Колесо ↓"), "mouse_up": I18n.tr("Колесо ↑"), "mouse:272": I18n.tr("ЛКМ"), "mouse:273": I18n.tr("ПКМ"), "mouse:274": I18n.tr("СКМ"),
            "XF86AudioRaiseVolume": I18n.tr("Громк+"), "XF86AudioLowerVolume": I18n.tr("Громк−"), "XF86AudioMute": "Mute",
            "XF86AudioMicMute": "MicMute", "XF86MonBrightnessUp": I18n.tr("Ярк+"), "XF86MonBrightnessDown": I18n.tr("Ярк−"),
            "XF86AudioPlay": "Play", "XF86AudioPause": "Pause", "XF86AudioNext": "Next", "XF86AudioPrev": "Prev",
            "minus": "−", "equal": "=", "grave": "`", "BackSpace": "⌫", "Delete": "Del"
        };
        return map[k] ?? k;
    }
    function prettyMod(m: string): string {
        return ({ "SUPER": "󰖳", "CTRL": "Ctrl", "ALT": "Alt", "SHIFT": "Shift" })[m] ?? m;
    }
    function keycaps(bind): var {
        const m = normMods(bind.mods);
        return [...(m ? m.split(" ").map(prettyMod) : []), prettyKey(bind.key)];
    }

    function conflicts(bind, ignoreIndex: int): var {
        const c = combo(bind).toLowerCase();
        return Settings.binds
            .map((x, i) => ({ x, i }))
            .filter(o => o.i !== ignoreIndex && o.x.enabled !== false && combo(o.x).toLowerCase() === c);
    }

    function update(index: int, bind): void {
        const l = Settings.copy(Settings.binds);
        if (index < 0) l.push(bind);
        else l[index] = bind;
        Settings.binds = l;
    }
    function remove(index: int): void {
        const l = Settings.copy(Settings.binds);
        l.splice(index, 1);
        Settings.binds = l;
    }
    function reset(): void { Settings.binds = defaults(); }

    // Qt.Key → имя клавиши xkb, как его понимает Hyprland
    function keyName(key: int, text: string): string {
        const special = {
            [Qt.Key_Space]: "SPACE", [Qt.Key_Escape]: "ESCAPE", [Qt.Key_Tab]: "TAB", [Qt.Key_Backtab]: "TAB",
            [Qt.Key_Return]: "RETURN", [Qt.Key_Enter]: "RETURN", [Qt.Key_Backspace]: "BackSpace",
            [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
            [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Print]: "Print",
            [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
            [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Slash]: "slash", [Qt.Key_Backslash]: "backslash",
            [Qt.Key_Minus]: "minus", [Qt.Key_Equal]: "equal", [Qt.Key_Plus]: "equal", [Qt.Key_Semicolon]: "semicolon",
            [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_QuoteLeft]: "grave", [Qt.Key_BracketLeft]: "bracketleft",
            [Qt.Key_BracketRight]: "bracketright",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
            [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev"
        };
        if (special[key]) return special[key];
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24) return "F" + (key - Qt.Key_F1 + 1);
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
        // русская раскладка: берём латинскую клавишу на том же месте
        const ru = I18n.tr("йцукенгшщзхъфывапролджэячсмитьбю"), en = "qwertyuiop[]asdfghjkl;'zxcvbnm,.";
        const i = ru.indexOf((text ?? "").toLowerCase());
        if (i >= 0) {
            const ch = en[i];
            return /[a-z]/.test(ch) ? ch.toUpperCase() : keyName(({ "[": Qt.Key_BracketLeft, "]": Qt.Key_BracketRight, ";": Qt.Key_Semicolon, "'": Qt.Key_Apostrophe, ",": Qt.Key_Comma, ".": Qt.Key_Period })[ch], "");
        }
        return "";
    }

    function isModifierKey(key: int): bool {
        return [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].includes(key);
    }

    function modsFromEvent(m: int): string {
        const out = [];
        if (m & Qt.MetaModifier) out.push("SUPER");
        if (m & Qt.ControlModifier) out.push("CTRL");
        if (m & Qt.AltModifier) out.push("ALT");
        if (m & Qt.ShiftModifier) out.push("SHIFT");
        return out.join(" ");
    }
}
