import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Мониторы")
    subtitle: I18n.tr("Разрешение, частота, масштаб и расположение. Новые настройки сначала пробуются: если не нажать «Оставить», через 15 секунд вернутся прежние.")

    // черновик: правим его, «Применить» пробует на мониторах
    property var draft: []
    property string sel: ""
    property bool dirty: false

    function reload(): void {
        if (dirty || Displays.pending) return;
        draft = Displays.currentAll();
        if (!draft.some(c => c.name === sel)) sel = draft[0]?.name ?? "";
    }
    Connections {
        target: Displays
        function onMonitorsChanged(): void { page.reload(); }
        function onPendingChanged(): void { if (!Displays.pending) { page.dirty = false; page.reload(); } }
    }
    Component.onCompleted: { Displays.refresh(); reload(); }

    readonly property var cur: draft.find(c => c.name === sel) ?? null
    readonly property var mon: Displays.byName(sel)
    readonly property var modes: Displays.modes(mon)
    readonly property string res: cur ? cur.mode.split("@")[0] : ""

    function set(field: string, value): void {
        draft = draft.map(c => c.name === sel ? Object.assign({}, c, { [field]: value }) : c);
        dirty = true;
    }
    function move(name: string, x: int, y: int): void {
        draft = draft.map(c => c.name === name ? Object.assign({}, c, { x, y }) : c);
        // левый верхний угол всей раскладки — в 0,0
        const on = draft.filter(c => c.enabled && !c.mirror);
        const mx = Math.min(...on.map(c => c.x)), my = Math.min(...on.map(c => c.y));
        draft = draft.map(c => Object.assign({}, c, { x: c.x - mx, y: c.y - my }));
        dirty = true;
    }

    // ---- проба: оставить или вернуть ----
    Rectangle {
        visible: Displays.pending
        Layout.fillWidth: true
        implicitHeight: 64
        radius: Theme.radius
        color: Theme.alpha(Theme.accent, 0.14)
        border.width: 1
        border.color: Theme.accent
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            MIcon { icon: "timer"; color: Theme.accent; size: 22 }
            StyledText {
                Layout.fillWidth: true
                text: I18n.tr("Оставить эти настройки? Прежние вернутся через {0} с", Displays.countdown)
                color: Theme.text
                font.bold: true
                wrapMode: Text.WordWrap
            }
            SButton { text: I18n.tr("Вернуть"); onClicked: Displays.revert() }
            SButton { text: I18n.tr("Оставить"); primary: true; onClicked: Displays.keep() }
        }
    }

    // ---- схема ----
    SCard {
        title: I18n.tr("Расположение")
        icon: "monitor"

        Item {
            id: canvas
            Layout.fillWidth: true
            Layout.preferredHeight: 240
            Layout.margins: 10

            readonly property var shown: page.draft.filter(c => c.enabled && !c.mirror)
            readonly property var rects: shown.map(c => Object.assign({ name: c.name }, Displays.logical(c), { x: c.x, y: c.y }))
            readonly property real minX: Math.min(0, ...rects.map(r => r.x))
            readonly property real minY: Math.min(0, ...rects.map(r => r.y))
            readonly property real spanW: Math.max(1, ...rects.map(r => r.x + r.w)) - minX
            readonly property real spanH: Math.max(1, ...rects.map(r => r.y + r.h)) - minY
            // запас по краям, чтобы было куда тащить
            readonly property real k: Math.min((width - 40) / (spanW * 1.5), (height - 40) / (spanH * 1.3))
            readonly property real ox: (width - spanW * k) / 2
            readonly property real oy: (height - spanH * k) / 2

            Rectangle { anchors.fill: parent; radius: Theme.radiusSmall; color: Theme.crust }

            Repeater {
                model: canvas.rects
                Rectangle {
                    id: box
                    required property var modelData
                    readonly property bool picked: modelData.name === page.sel
                    readonly property bool main: modelData.name === (Settings.displays.primary || page.draft[0]?.name)
                    x: canvas.ox + (modelData.x - canvas.minX) * canvas.k
                    y: canvas.oy + (modelData.y - canvas.minY) * canvas.k
                    width: modelData.w * canvas.k
                    height: modelData.h * canvas.k
                    radius: 6
                    color: picked ? Theme.alpha(Theme.accent, 0.25) : Theme.surface0
                    border.width: 2
                    border.color: picked ? Theme.accent : Theme.surface2
                    z: drag.drag.active ? 2 : 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        StyledText { Layout.alignment: Qt.AlignHCenter; text: box.modelData.name; font.bold: true; color: box.picked ? Theme.accent : Theme.text }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: (page.draft.find(c => c.name === box.modelData.name)?.mode ?? "").replace(/\.00$/, "") + I18n.tr(" Гц")
                            color: Theme.subtext0
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        MIcon { visible: box.main; Layout.alignment: Qt.AlignHCenter; icon: "star"; fill: true; size: 14; color: Theme.yellow }
                    }

                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        cursorShape: canvas.rects.length > 1 ? Qt.SizeAllCursor : Qt.PointingHandCursor
                        drag.target: canvas.rects.length > 1 ? box : null
                        drag.threshold: 4
                        onPressed: page.sel = box.modelData.name
                        onReleased: {
                            if (!drag.drag.active && box.x === canvas.ox + (box.modelData.x - canvas.minX) * canvas.k) return;
                            // в координаты Hyprland + прилипание к краям соседей
                            let x = Math.round((box.x - canvas.ox) / canvas.k + canvas.minX);
                            let y = Math.round((box.y - canvas.oy) / canvas.k + canvas.minY);
                            const w = box.modelData.w, h = box.modelData.h, snap = 120;
                            let bx = null, by = null;
                            for (const o of canvas.rects) {
                                if (o.name === box.modelData.name) continue;
                                for (const c of [o.x - w, o.x + o.w, o.x, o.x + o.w - w])
                                    if (Math.abs(c - x) < snap && (bx === null || Math.abs(c - x) < Math.abs(bx - x))) bx = c;
                                for (const c of [o.y - h, o.y + o.h, o.y, o.y + o.h - h])
                                    if (Math.abs(c - y) < snap && (by === null || Math.abs(c - y) < Math.abs(by - y))) by = c;
                            }
                            page.move(box.modelData.name, bx ?? x, by ?? y);
                        }
                    }
                }
            }

            StyledText {
                visible: canvas.rects.length > 1
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 8
                text: I18n.tr("Перетащите монитор, чтобы поставить его рядом с другим")
                color: Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: page.dirty ? I18n.tr("Есть неприменённые изменения") : I18n.tr("Как сейчас")
                color: page.dirty ? Theme.peach : Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
            }
            SButton {
                visible: page.dirty
                text: I18n.tr("Отменить")
                onClicked: { page.dirty = false; page.reload(); }
            }
            SButton {
                icon: "check"
                text: I18n.tr("Применить")
                primary: true
                enabled_: page.dirty && !Displays.pending
                onClicked: if (enabled_) Displays.tryApply(page.draft)
            }
        }
    }

    // ---- выбранный монитор ----
    SCard {
        visible: page.cur !== null
        title: page.mon ? Displays.title(page.mon) : ""
        icon: "desktop_windows"

        SRow {
            icon: "power_settings_new"
            title: I18n.tr("Включён")
            desc: page.draft.filter(c => c.enabled).length <= 1 && page.cur?.enabled ? I18n.tr("Последний включённый монитор выключить нельзя") : ""
            SSwitch {
                checked: page.cur?.enabled ?? true
                onToggled: v => { if (v || page.draft.filter(c => c.enabled).length > 1) page.set("enabled", v); }
            }
        }
        SRow {
            visible: page.cur?.enabled ?? false
            icon: "aspect_ratio"
            title: I18n.tr("Разрешение")
            SDropdown {
                options: Object.keys(page.modes)
                    .sort((a, b) => Number(b.split("x")[0]) * Number(b.split("x")[1]) - Number(a.split("x")[0]) * Number(a.split("x")[1]))
                    .map(r => ({ value: r, label: r.replace("x", " × ") }))
                current: page.res
                onPicked: v => page.set("mode", v + "@" + (page.modes[v]?.[0] ?? "60.00"))
            }
        }
        SRow {
            visible: page.cur?.enabled ?? false
            icon: "speed"
            title: I18n.tr("Частота")
            SDropdown {
                options: (page.modes[page.res] ?? []).map(r => ({ value: r, label: Number(r).toFixed(Number(r) % 1 ? 2 : 0) + I18n.tr(" Гц") }))
                current: page.cur ? page.cur.mode.split("@")[1] : ""
                onPicked: v => page.set("mode", page.res + "@" + v)
            }
        }
        SRow {
            visible: page.cur?.enabled ?? false
            icon: "zoom_in"
            title: I18n.tr("Масштаб")
            desc: I18n.tr("Больше — крупнее текст и окна")
            SSegment {
                options: [1, 1.25, 1.5, 1.75, 2].map(v => ({ value: v, label: Math.round(v * 100) + "%" }))
                current: page.cur?.scale ?? 1
                onPicked: v => page.set("scale", v)
            }
        }
        SRow {
            visible: page.cur?.enabled ?? false
            icon: "screen_rotation"
            title: I18n.tr("Поворот")
            SSegment {
                options: [{ value: 0, label: "0°" }, { value: 1, label: "90°" }, { value: 2, label: "180°" }, { value: 3, label: "270°" }]
                current: page.cur?.transform ?? 0
                onPicked: v => page.set("transform", v)
            }
        }
        SRow {
            visible: page.cur?.enabled ?? false
            icon: "motion_play"
            title: I18n.tr("Адаптивная частота (VRR)")
            desc: I18n.tr("FreeSync / G-Sync: монитор подстраивается под игру")
            SSegment {
                options: [{ value: 0, label: I18n.tr("Выкл") }, { value: 2, label: I18n.tr("В полноэкранном") }, { value: 1, label: I18n.tr("Всегда") }]
                current: page.cur?.vrr ?? 0
                onPicked: v => page.set("vrr", v)
            }
        }
        SRow {
            visible: (page.cur?.enabled ?? false) && page.draft.length > 1
            icon: "content_copy"
            title: I18n.tr("Повторять экран")
            desc: I18n.tr("Показывать то же, что на другом мониторе")
            SDropdown {
                options: [{ value: "", label: I18n.tr("Нет — свой рабочий стол") }]
                    .concat(page.draft.filter(c => c.name !== page.sel && c.enabled && !c.mirror).map(c => ({ value: c.name, label: c.name })))
                current: page.cur?.mirror ?? ""
                onPicked: v => page.set("mirror", v)
            }
        }
        SRow {
            visible: page.draft.length > 1
            icon: "star"
            title: I18n.tr("Основной")
            desc: I18n.tr("Здесь виджеты рабочего стола, заставка и панель, если она только на одном мониторе")
            separator: false
            SSwitch {
                checked: (Settings.displays.primary || page.draft[0]?.name) === page.sel
                onToggled: v => Settings.displays.primary = v ? page.sel : ""
            }
        }
    }

    SCard {
        visible: page.draft.length > 1
        title: I18n.tr("Панель и остров")
        icon: "dock_to_bottom"
        SRow {
            icon: "view_day"
            title: I18n.tr("Где показывать")
            separator: false
            SSegment {
                options: [{ value: "all", label: I18n.tr("На всех мониторах") }, { value: "primary", label: I18n.tr("Только на основном") }]
                current: Settings.displays.bars
                onPicked: v => Settings.displays.bars = v
            }
        }
    }

    SCard {
        title: I18n.tr("Сброс")
        icon: "restart_alt"
        SRow {
            icon: "settings_backup_restore"
            title: I18n.tr("Забыть свои настройки мониторов")
            desc: Settings.displays.monitors.length ? I18n.tr("Дальше решает Hyprland (и ~/.config/hypr/monitors.lua)") : I18n.tr("Своих настроек пока нет")
            separator: false
            SButton {
                text: I18n.tr("Сбросить")
                danger: true
                enabled_: Settings.displays.monitors.length > 0
                onClicked: if (enabled_) Displays.reset()
            }
        }
    }
}
