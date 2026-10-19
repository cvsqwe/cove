import QtQuick
import QtQuick.Layouts
import qs.kit
import qs.services

// Идущие операции: копирование, перемещение, корзина — с прогрессом и отменой
Rectangle {
    id: root
    visible: Ops.jobs.length > 0
    width: 330
    height: col.implicitHeight + 24
    radius: Cove.radius
    color: Cove.mantle
    border.color: Cove.surface1

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        Repeater {
            model: Ops.jobs
            ColumnLayout {
                id: j
                required property var modelData
                readonly property real frac: modelData.total > 0 ? Math.min(1, modelData.done / modelData.total) : 0
                Layout.fillWidth: true
                spacing: 6
                RowLayout {
                    spacing: 10
                    KIcon { icon: j.modelData.icon; color: Cove.accent }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        KText { Layout.fillWidth: true; text: j.modelData.title; font.bold: true }
                        KText {
                            Layout.fillWidth: true
                            text: (j.modelData.total > 100 ? Fmt.size(j.modelData.done) + " из " + Fmt.size(j.modelData.total) + "  " : "") + (j.modelData.file ?? "")
                            color: Cove.overlay1
                            font.pixelSize: Cove.fontSizeSmall
                            elide: Text.ElideMiddle
                        }
                    }
                    KButton { icon: "close"; flat: true; implicitWidth: 28; implicitHeight: 28; tip: "Отменить"; onClicked: Ops.cancel(j.modelData.id) }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 5
                    radius: 3
                    color: Cove.surface0
                    Rectangle {
                        width: parent.width * j.frac
                        height: parent.height
                        radius: 3
                        color: Cove.accent
                        Behavior on width { NumberAnimation { duration: 150 } }
                    }
                }
            }
        }
    }
}
