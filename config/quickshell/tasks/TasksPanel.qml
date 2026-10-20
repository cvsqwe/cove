import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Диспетчер задач (Ctrl+Shift+Esc, клик по нагрузке в панели): приложения с их процессами,
// нагрузка CPU/памяти, «Завершить» и «Убить». Клик по строке — раскрыть процессы.
Drawer {
    id: root
    screen: Panels.screen

    side: "center"
    centerOffset: 60
    anim: "grow"
    drawerWidth: 820
    drawerHeight: Math.min(680, (screen?.height ?? 1080) - 160)
    grabKeyboard: true
    open: Panels.tasks
    onCloseRequested: Panels.tasks = false
    onOpenChanged: if (open) { search.text = ""; Qt.callLater(() => search.forceActiveFocus()); }

    property string sort: "cpu"          // cpu | mem | name
    property bool showSystem: false
    property var expanded: ({})

    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        const list = [];
        for (const g of Tasks.groups) {
            if (!showSystem && g.system && !/^\d+$/.test(q)) continue;
            if (q === "" || g.name.toLowerCase().includes(q) || g.key.toLowerCase().includes(q)) { list.push(g); continue; }
            // совпал PID или командная строка — только эти процессы: «Завершить» не тронет остальные
            const procs = g.procs.filter(p => String(p.pid) === q || p.cmd.toLowerCase().includes(q));
            if (procs.length) list.push(Object.assign({}, g, {
                procs, cpu: procs.reduce((a, p) => a + p.cpu, 0), mem: procs.reduce((a, p) => a + p.mem, 0),
                system: procs.every(p => p.uid !== Tasks.me)
            }));
        }
        const by = { cpu: (a, b) => b.cpu - a.cpu || b.mem - a.mem, mem: (a, b) => b.mem - a.mem, name: (a, b) => a.name.localeCompare(b.name) };
        return list.sort(by[sort]);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // шапка: нагрузка машины
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            MIcon { icon: "monitoring"; color: Theme.accent; size: 22 }
            StyledText { text: I18n.tr("Процессы"); font.bold: true; font.pixelSize: Theme.fontSizeLarge }
            Item { Layout.fillWidth: true }
            // модель постоянная, живые значения — внутри плитки: иначе каждый замер Sysmon
            // пересоздавал плитки с графиками, даже при закрытом окне
            Repeater {
                model: ["cpu", "ram", "gpu"]
                Rectangle {
                    id: tile
                    required property string modelData
                    readonly property bool live: root.open
                    implicitWidth: 150
                    implicitHeight: 46
                    radius: Theme.radiusSmall
                    color: Theme.mantle
                    clip: true
                    Sparkline {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 26
                        values: !tile.live ? [] : tile.modelData === "cpu" ? Sysmon.cpuHistory : tile.modelData === "ram" ? Sysmon.ramHistory : Sysmon.gpuHistory
                        color: tile.modelData === "cpu" ? Theme.accent : tile.modelData === "ram" ? Theme.accent2 : Theme.peach
                        opacity: 0.55
                    }
                    Column {
                        x: 10; y: 6
                        StyledText {
                            text: tile.modelData === "cpu" ? I18n.tr("ЦП") : tile.modelData === "ram" ? I18n.tr("Память") : "GPU"
                            color: Theme.overlay1
                            font.pixelSize: Theme.fontSizeSmall - 1
                        }
                        StyledText {
                            text: !tile.live ? "" : tile.modelData === "cpu" ? Math.round(Sysmon.cpu * 100) + "%"
                                : tile.modelData === "ram" ? `${Sysmon.ramUsedGb.toFixed(1)} / ${Sysmon.ramTotalGb.toFixed(0)} ${I18n.tr("ГБ")}`
                                : Math.round(Sysmon.gpu * 100) + "%"
                            font.bold: true
                            font.pixelSize: Theme.fontSizeSmall + 1
                        }
                    }
                }
            }
        }

        // поиск, сортировка, системные
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            SField {
                id: search
                Layout.fillWidth: true
                placeholderText: I18n.tr("Найти приложение, процесс или PID…")
                Keys.onEscapePressed: Panels.tasks = false
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
                // Delete — завершить выбранное, Shift+Delete — убить
                Keys.onDeletePressed: e => {
                    const g = root.shown[list.currentIndex];
                    if (!g || text !== "" && cursorPosition !== text.length) { e.accepted = false; return; }
                    (e.modifiers & Qt.ShiftModifier) ? Tasks.kill(g) : Tasks.end(g);
                }
                Keys.onReturnPressed: { const g = root.shown[list.currentIndex]; if (g) root.toggleExpand(g.key); }
            }
            SSegment {
                options: [{ value: "cpu", label: I18n.tr("ЦП") }, { value: "mem", label: I18n.tr("Память") }, { value: "name", label: I18n.tr("Имя") }]
                current: root.sort
                onPicked: v => root.sort = v
            }
            Chip {
                icon: "shield_person"
                text: I18n.tr("Системные")
                active: root.showSystem
                onClicked: root.showSystem = !root.showSystem
            }
        }

        // подписи колонок
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 12
            StyledText { Layout.fillWidth: true; text: I18n.tr("Приложение"); color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
            StyledText { Layout.preferredWidth: 120; text: I18n.tr("ЦП"); color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
            StyledText { Layout.preferredWidth: 80; horizontalAlignment: Text.AlignRight; text: I18n.tr("Память"); color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
            Item { Layout.preferredWidth: 196 }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: root.shown.map(g => g.key) }
            highlightMoveDuration: 0
            highlight: Rectangle { radius: Theme.radiusSmall; color: Theme.surface0 }

            delegate: TaskRow {
                width: list.width
                group: root.shown.find(g => g.key === modelData) ?? null
                expanded: !!root.expanded[modelData]
                current: ListView.isCurrentItem
                onToggle: root.toggleExpand(modelData)
                onHovered: list.currentIndex = index
            }

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: Tasks.procs.length ? I18n.tr("Ничего не найдено") : I18n.tr("Собираю процессы…")
                color: Theme.overlay0
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: I18n.tr("Клик — процессы приложения · Delete — завершить · Shift+Delete — убить · Esc — закрыть")
            color: Theme.overlay0
            font.pixelSize: Theme.fontSizeSmall - 1
            horizontalAlignment: Text.AlignHCenter
        }
    }

    function toggleExpand(k: string): void {
        const e = Object.assign({}, expanded);
        e[k] = !e[k];
        expanded = e;
    }
}
