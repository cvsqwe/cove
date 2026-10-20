import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Контекстное меню рабочего стола (ПКМ по виджету или по пустому месту).
// items: [{ kind: "header", icon, label } | { kind: "sep" } | { kind: "seg", label, options, current, pick(v) }
//        | { icon, label, checked?, danger?, keep?, run() }]
// keep — меню остаётся открытым после клика (переключатели).
Rectangle {
    id: root

    property var items: []
    signal close()

    implicitWidth: Math.max(240, col.implicitWidth + 12)
    implicitHeight: col.implicitHeight + 12
    radius: Theme.radius + 2
    color: Theme.panel
    border.width: 1
    border.color: Theme.surface0

    // клики внутри меню не должны закрывать его через фон
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    ColumnLayout {
        id: col
        x: 6
        y: 6
        width: root.width - 12
        spacing: 1

        Repeater {
            model: root.items

            Loader {
                id: row
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: modelData.kind === "sep" ? sep : modelData.kind === "header" ? header
                    : modelData.kind === "seg" ? seg : item

                Component {
                    id: sep
                    Item { implicitHeight: 9; Rectangle { anchors.centerIn: parent; width: parent.width - 8; height: 1; color: Theme.surface0 } }
                }
                Component {
                    id: header
                    RowLayout {
                        spacing: 8
                        Item { implicitWidth: 2 }
                        MIcon { icon: row.modelData.icon ?? "widgets"; size: Theme.fontSize; color: Theme.accent }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            text: row.modelData.label
                            font.bold: true
                            elide: Text.ElideRight
                        }
                    }
                }
                Component {
                    id: seg
                    ColumnLayout {
                        spacing: 4
                        StyledText {
                            Layout.leftMargin: 10
                            Layout.topMargin: 4
                            text: row.modelData.label
                            color: Theme.overlay1
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        SSegment {
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            Layout.bottomMargin: 4
                            options: row.modelData.options
                            current: row.modelData.current
                            onPicked: v => row.modelData.pick(v)
                        }
                    }
                }
                Component {
                    id: item
                    Rectangle {
                        implicitWidth: line.implicitWidth + 20
                        implicitHeight: 32
                        radius: Theme.radiusSmall + 2
                        color: m.containsMouse ? (row.modelData.danger ? Theme.alpha(Theme.red, 0.18) : Theme.surface0) : "transparent"
                        RowLayout {
                            id: line
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            MIcon {
                                visible: !!row.modelData.icon
                                icon: row.modelData.icon ?? ""
                                size: Theme.fontSize + 1
                                color: row.modelData.danger ? Theme.red : Theme.subtext1
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.label
                                color: row.modelData.danger ? Theme.red : Theme.text
                                elide: Text.ElideRight
                            }
                            MIcon {
                                visible: row.modelData.checked !== undefined
                                icon: row.modelData.checked ? "toggle_on" : "toggle_off"
                                fill: !!row.modelData.checked
                                size: Theme.fontSizeLarge + 4
                                color: row.modelData.checked ? Theme.accent : Theme.overlay0
                            }
                        }
                        MouseArea {
                            id: m
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const d = row.modelData;
                                if (!d.keep) root.close();
                                d.run();
                            }
                        }
                    }
                }
            }
        }
    }
}
