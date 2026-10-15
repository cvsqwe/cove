pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Пресеты стиля панели. Пресет — только набор параметров Settings.bar;
// цвета, радиусы и высота всегда берутся из темы, поэтому любой пресет в общем стиле системы.
Singleton {
    id: root

    readonly property var keys: ["style", "capsules", "capsuleFill", "shape", "bodyOpacity", "iconColors", "separators", "labels"]

    readonly property var presets: [
        { name: I18n.tr("Капсулы"), desc: I18n.tr("Модули группами в тёмных капсулах"),
          cfg: { style: "floating", capsules: "groups", capsuleFill: "dark", shape: "round", bodyOpacity: 1.0, iconColors: "mono", separators: false, labels: "hover" } },
        { name: I18n.tr("Стекло"), desc: I18n.tr("Полупрозрачная полоса с размытием, без подложек"),
          cfg: { style: "floating", capsules: "none", capsuleFill: "dark", shape: "round", bodyOpacity: 0.7, iconColors: "mono", separators: true, labels: "hover" } },
        { name: I18n.tr("Острова"), desc: I18n.tr("Без полосы — капсулы прямо над обоями"),
          cfg: { style: "floating", capsules: "groups", capsuleFill: "dark", shape: "round", bodyOpacity: 0.0, iconColors: "mono", separators: false, labels: "hover" } },
        { name: I18n.tr("Плитки"), desc: I18n.tr("Мягкие светлые плитки у каждого модуля"),
          cfg: { style: "floating", capsules: "each", capsuleFill: "light", shape: "soft", bodyOpacity: 1.0, iconColors: "mono", separators: false, labels: "hover" } },
        { name: I18n.tr("Контур"), desc: I18n.tr("Прозрачные капсулы с тонкой обводкой"),
          cfg: { style: "floating", capsules: "each", capsuleFill: "outline", shape: "round", bodyOpacity: 0.85, iconColors: "mono", separators: false, labels: "hover" } },
        { name: I18n.tr("Чёлка"), desc: I18n.tr("Остров — вырез у края, по бокам стеклянные крылья"),
          cfg: { style: "notch", capsules: "groups", capsuleFill: "dark", shape: "round", bodyOpacity: 1.0, iconColors: "mono", separators: false, labels: "hover" } },
        { name: I18n.tr("Капли"), desc: I18n.tr("Модули свисают с края экрана, как остров"),
          cfg: { style: "drops", capsules: "groups", capsuleFill: "dark", shape: "round", bodyOpacity: 1.0, iconColors: "mono", separators: false, labels: "hover" } },
        { name: I18n.tr("Классика"), desc: I18n.tr("Сплошная панель у края экрана"),
          cfg: { style: "docked", capsules: "none", capsuleFill: "dark", shape: "soft", bodyOpacity: 1.0, iconColors: "mono", separators: false, labels: "hover" } }
    ]

    function same(a, b): bool { return typeof a === "number" ? Math.abs(a - b) < 0.01 : a === b; }
    function matches(cfg): bool { return keys.every(k => same(Settings.bar[k], cfg[k])); }

    // имя пресета, совпадающего с текущими настройками, или "" — ручная настройка
    readonly property string current: {
        const b = Settings.bar;
        void [b.style, b.capsules, b.capsuleFill, b.shape, b.bodyOpacity, b.iconColors, b.separators, b.labels];
        return presets.find(p => matches(p.cfg))?.name ?? "";
    }

    function apply(cfg): void {
        for (const k of keys) Settings.bar[k] = cfg[k];
    }
}
