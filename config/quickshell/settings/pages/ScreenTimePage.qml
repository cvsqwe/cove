import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Экранное время")
    subtitle: I18n.tr("Сколько времени за день у какого приложения был фокус. Пока вы отошли или экран заблокирован, время не идёт.")

    readonly property string day: ScreenTime.today
    readonly property var apps: { ScreenTime.days; return ScreenTime.apps(page.day); }
    readonly property int total: { ScreenTime.days; return ScreenTime.total(page.day); }
    readonly property var week: { ScreenTime.days; return ScreenTime.week(); }
    readonly property int weekMax: Math.max(3600, ...week.map(d => d.secs))
    readonly property int avg: Math.round(week.reduce((a, d) => a + d.secs, 0) / Math.max(1, week.filter(d => d.secs > 0).length))

    function appName(cls: string): string { return Tasks.entryFor(cls)?.name ?? cls; }
    function appIcon(cls: string): string { const e = Tasks.entryFor(cls); return e?.icon ? Quickshell.iconPath(e.icon, true) : ""; }

    SCard {
        title: I18n.tr("Сегодня")
        icon: "hourglass"

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 14

            // главное число дня
            RowLayout {
                spacing: 16
                StyledText { text: ScreenTime.fmt(page.total); font.pixelSize: 34; font.bold: true }
                StyledText {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 6
                    visible: page.avg > 0
                    text: I18n.tr("в среднем за неделю {0}", ScreenTime.fmt(page.avg))
                    color: Theme.overlay1
                }
            }

            StyledText {
                visible: page.apps.length === 0
                text: ScreenTime.enabled ? I18n.tr("Пока пусто: время копится, пока вы работаете.") : I18n.tr("Подсчёт выключен.")
                color: Theme.overlay0
            }

            // приложения: полоска — доля от самого долгого
            Repeater {
                model: page.apps.slice(0, 12)
                RowLayout {
                    id: appRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    Item {
                        implicitWidth: 24
                        implicitHeight: 24
                        IconImage { id: ai; anchors.fill: parent; source: page.appIcon(appRow.modelData.app); visible: status === Image.Ready }
                        MIcon { anchors.centerIn: parent; visible: !ai.visible; icon: "apps"; color: Theme.overlay1; size: 18 }
                    }
                    StyledText { Layout.preferredWidth: 170; text: page.appName(appRow.modelData.app); elide: Text.ElideRight }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 8
                        Rectangle { anchors.fill: parent; radius: 4; color: Theme.surface0 }
                        Rectangle {
                            width: Math.max(8, parent.width * appRow.modelData.secs / Math.max(1, page.apps[0].secs))
                            height: parent.height
                            radius: 4
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                    StyledText {
                        Layout.preferredWidth: 96
                        horizontalAlignment: Text.AlignRight
                        text: ScreenTime.fmt(appRow.modelData.secs)
                        color: Theme.subtext1
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }

    SCard {
        title: I18n.tr("Неделя")
        icon: "bar_chart"

        Item {
            id: chart
            Layout.fillWidth: true
            Layout.margins: 16
            implicitHeight: 190
            property int hovered: -1

            // сетка: линия часа и базовая линия
            Repeater {
                model: [0, 3600 * Math.ceil(page.weekMax / 3600 / 2), 3600 * Math.ceil(page.weekMax / 3600)]
                Item {
                    required property int modelData
                    readonly property real yy: 150 - 150 * modelData / (3600 * Math.ceil(page.weekMax / 3600))
                    width: chart.width
                    y: yy
                    Rectangle { x: 36; width: parent.width - 36; height: 1; color: parent.modelData === 0 ? Theme.surface2 : Theme.surface0 }
                    StyledText {
                        y: -8
                        text: parent.modelData === 0 ? "0" : Math.round(parent.modelData / 3600) + I18n.tr(" ч")
                        color: Theme.overlay0
                        font.pixelSize: Theme.fontSizeSmall - 1
                    }
                }
            }

            Row {
                x: 36
                width: parent.width - 36
                Repeater {
                    model: page.week
                    Item {
                        id: col
                        required property var modelData
                        required property int index
                        readonly property real full: 3600 * Math.ceil(page.weekMax / 3600)
                        width: parent.width / 7
                        height: 190
                        Rectangle {
                            id: bar
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: -150
                            width: Math.min(28, parent.width * 0.5)
                            height: Math.max(col.modelData.secs > 0 ? 3 : 0, 150 * col.modelData.secs / col.full)
                            topLeftRadius: 4
                            topRightRadius: 4
                            color: col.modelData.key === page.day ? Theme.accent : Theme.alpha(Theme.accent, chart.hovered === col.index ? 0.75 : 0.5)
                            Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 158
                            text: col.modelData.label
                            color: col.modelData.key === page.day ? Theme.text : Theme.overlay1
                            font.bold: col.modelData.key === page.day
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        // подсказка при наведении: зона больше столбика
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: chart.hovered = col.index
                            onExited: if (chart.hovered === col.index) chart.hovered = -1
                        }
                        Rectangle {
                            visible: chart.hovered === col.index
                            z: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.max(0, 150 - bar.height - height - 6)
                            width: tip.implicitWidth + 16
                            height: tip.implicitHeight + 8
                            radius: height / 2
                            color: Theme.crust
                            border.width: 1
                            border.color: Theme.surface1
                            StyledText { id: tip; anchors.centerIn: parent; text: ScreenTime.fmt(col.modelData.secs); font.pixelSize: Theme.fontSizeSmall }
                        }
                    }
                }
            }
        }
    }

    SCard {
        title: I18n.tr("Настройки")
        icon: "tune"
        SRow {
            icon: "hourglass"
            title: I18n.tr("Считать экранное время")
            desc: I18n.tr("Хранится только на этом компьютере, последние 60 дней")
            SSwitch { checked: Settings.general.screenTime; onToggled: v => Settings.general.screenTime = v }
        }
        SRow {
            icon: "delete"
            title: I18n.tr("Очистить историю")
            separator: false
            SButton { text: I18n.tr("Очистить"); danger: true; onClicked: { ScreenTime.days = {}; ScreenTime.save(); } }
        }
    }
}
