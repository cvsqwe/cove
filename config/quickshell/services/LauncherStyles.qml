pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Пресеты вида лаунчера: только набор Settings.launcher, цвета и шрифты — из темы.
Singleton {
    id: root

    readonly property var keys: ["position", "layout", "density", "iconSize", "descriptions", "header", "width", "height"]

    readonly property var presets: [
        { name: I18n.tr("Ящик"), desc: I18n.tr("Слева под панелью, список с описаниями"),
          cfg: { position: "left", layout: "list", density: "normal", iconSize: 32, descriptions: true, header: "greeting", width: 560, height: 540 } },
        { name: "Spotlight", desc: I18n.tr("Строка поиска по центру, компактно"),
          cfg: { position: "center", layout: "list", density: "compact", iconSize: 28, descriptions: false, header: "none", width: 680, height: 440 } },
        { name: I18n.tr("Сетка"), desc: I18n.tr("Крупные иконки плиткой по центру"),
          cfg: { position: "center", layout: "grid", density: "normal", iconSize: 48, descriptions: true, header: "greeting", width: 820, height: 580 } },
        { name: I18n.tr("Минимал"), desc: I18n.tr("Маленький список без лишнего"),
          cfg: { position: "center", layout: "list", density: "compact", iconSize: 22, descriptions: false, header: "none", width: 500, height: 360 } },
        { name: I18n.tr("Справа"), desc: I18n.tr("Ящик у правого края, крупнее"),
          cfg: { position: "right", layout: "list", density: "normal", iconSize: 36, descriptions: true, header: "greeting", width: 520, height: 640 } }
    ]

    function matches(cfg): bool { return keys.every(k => Settings.launcher[k] === cfg[k]); }
    readonly property string current: {
        const l = Settings.launcher;
        void [l.position, l.layout, l.density, l.iconSize, l.descriptions, l.header, l.width, l.height];
        return presets.find(p => matches(p.cfg))?.name ?? "";
    }
    function apply(cfg): void { for (const k of keys) Settings.launcher[k] = cfg[k]; }
}
