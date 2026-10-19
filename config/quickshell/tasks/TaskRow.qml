import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Строка диспетчера задач: приложение (сумма по процессам), раскрывается в список процессов.
Item {
    id: row

    property var group: null
    property bool expanded: false
    property bool current: false
    signal toggle()
    signal hovered()

    readonly property var g: group ?? { name: "", icon: "", cpu: 0, mem: 0, procs: [], system: false, key: "" }
    implicitHeight: col.implicitHeight

    function cpuText(v: real): string { const p = v * 100; return p >= 10 ? Math.round(p) + "%" : p.toFixed(1) + "%"; }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 0

        // приложение
        Item {
            Layout.fillWidth: true
            implicitHeight: 52

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Item {
                    implicitWidth: 28
                    implicitHeight: 28
                    IconImage {
                        id: ico
                        anchors.fill: parent
                        source: row.g.icon ? Quickshell.iconPath(row.g.icon, true) : ""
                        visible: status === Image.Ready
                    }
                    MIcon { anchors.centerIn: parent; visible: !ico.visible; icon: row.g.system ? "settings" : "terminal"; color: Theme.overlay1; size: 20 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MIcon { visible: row.g.system; icon: "shield_person"; size: 13; color: Theme.overlay1 }
                        StyledText { Layout.fillWidth: true; text: row.g.name; font.bold: row.current; elide: Text.ElideRight }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: I18n.plural(row.g.procs.length, "процесс", "процесса", "процессов").replace(/^/, row.g.procs.length + " ")
                            + (row.g.key !== row.g.name ? " · " + row.g.key : "")
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSizeSmall - 1
                        elide: Text.ElideRight
                    }
                }
                // ЦП: число и полоска
                ColumnLayout {
                    // полоска внутри с fillWidth растянула бы и саму колонку — ширина жёсткая
                    Layout.fillWidth: false
                    Layout.preferredWidth: 120
                    Layout.maximumWidth: 120
                    spacing: 3
                    StyledText {
                        text: row.cpuText(row.g.cpu)
                        color: row.g.cpu > 0.5 ? Theme.red : row.g.cpu > 0.15 ? Theme.peach : Theme.text
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.features: { "tnum": 1 }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: Theme.surface0
                        Rectangle {
                            width: parent.width * Math.min(1, row.g.cpu * 2)   // половина машины — уже «полно»
                            height: parent.height
                            radius: 2
                            color: row.g.cpu > 0.5 ? Theme.red : Theme.accent
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                }
                StyledText {
                    Layout.preferredWidth: 80
                    horizontalAlignment: Text.AlignRight
                    text: Tasks.fmtMem(row.g.mem)
                    font.pixelSize: Theme.fontSizeSmall + 1
                    font.features: { "tnum": 1 }
                }
                Row {
                    Layout.preferredWidth: 196
                    layoutDirection: Qt.RightToLeft
                    spacing: 6
                    opacity: mouse.containsMouse || row.current ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                    SButton { text: I18n.tr("Убить"); danger: true; implicitHeight: 30; onClicked: Tasks.kill(row.g) }
                    SButton { text: I18n.tr("Завершить"); implicitHeight: 30; onClicked: Tasks.end(row.g) }
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: row.hovered()
                onClicked: row.toggle()
            }
        }

        // процессы приложения
        Repeater {
            model: row.expanded ? row.g.procs.slice(0, 40) : []
            Item {
                id: pr
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 32
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 52
                    anchors.rightMargin: 12
                    spacing: 12
                    StyledText { Layout.preferredWidth: 56; text: pr.modelData.pid; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; font.features: { "tnum": 1 } }
                    StyledText {
                        Layout.fillWidth: true
                        text: pr.modelData.cmd
                        color: Theme.subtext0
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideMiddle
                    }
                    StyledText { Layout.preferredWidth: 60; text: row.cpuText(pr.modelData.cpu); font.pixelSize: Theme.fontSizeSmall; font.features: { "tnum": 1 } }
                    StyledText { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight; text: Tasks.fmtMem(pr.modelData.mem); font.pixelSize: Theme.fontSizeSmall; font.features: { "tnum": 1 } }
                    IconButton {
                        size: 26; iconSize: 13
                        icon: "close"
                        onClicked: Tasks.sendSignal([pr.modelData.pid], "TERM", pr.modelData.uid !== Tasks.me)
                    }
                }
            }
        }
    }
}
