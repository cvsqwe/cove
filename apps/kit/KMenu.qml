import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Контекстное меню. open(x, y, items) — координаты в родителе меню;
// пункт: { text, icon, shortcut, danger, enabled, sep, run: function() {} }
Popup {
    id: root
    property var items: []

    function open_(px: real, py: real, list: var): void {
        items = list;
        x = px; y = py;
        open();
        // не вылезать за окно
        Qt.callLater(() => {
            const w = parent.width, h = parent.height;
            if (x + width > w - 6) x = Math.max(6, w - width - 6);
            if (y + height > h - 6) y = Math.max(6, py - height);
        });
    }

    padding: 5
    width: Math.max(200, col.implicitWidth + 10)
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110 } NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 140; easing.type: Easing.OutCubic } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 80 } }
    background: Rectangle {
        color: Cove.mantle
        radius: Cove.radiusSmall + 4
        border.color: Cove.surface1
        border.width: 1
    }

    contentItem: ColumnLayout {
        id: col
        spacing: 1
        Repeater {
            model: root.items
            Item {
                id: it
                required property var modelData
                readonly property bool sep: modelData.sep === true
                readonly property bool ok: modelData.enabled !== false
                Layout.fillWidth: true
                implicitHeight: sep ? 9 : 32
                implicitWidth: sep ? 0 : r.implicitWidth + 20

                Rectangle {
                    visible: it.sep
                    anchors.centerIn: parent
                    width: parent.width - 12
                    height: 1
                    color: Cove.surface0
                }
                Rectangle {
                    visible: !it.sep
                    anchors.fill: parent
                    radius: Cove.radiusSmall
                    color: ma.containsMouse && it.ok ? (it.modelData.danger ? Cove.alpha(Cove.red, 0.18) : Cove.surface0) : "transparent"
                }
                RowLayout {
                    id: r
                    visible: !it.sep
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 10
                    spacing: 10
                    opacity: it.ok ? 1 : 0.4
                    Image {
                        visible: !!it.modelData.img
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        sourceSize: Qt.size(40, 40)
                        source: it.modelData.img ? (it.modelData.img.startsWith("/") ? "file://" + it.modelData.img : Quickshell.iconPath(it.modelData.img, "application-x-executable")) : ""
                        asynchronous: true
                    }
                    KIcon {
                        visible: !it.modelData.img
                        Layout.preferredWidth: 20
                        icon: it.modelData.check !== undefined ? (it.modelData.check ? "check" : "") : (it.modelData.icon ?? "")
                        size: 16
                        color: it.modelData.danger ? Cove.red : Cove.subtext1
                    }
                    KText {
                        Layout.fillWidth: true
                        text: it.modelData.text ?? ""
                        color: it.modelData.danger ? Cove.red : Cove.text
                    }
                    KText {
                        visible: !!it.modelData.shortcut
                        text: it.modelData.shortcut ?? ""
                        color: Cove.overlay1
                        font.pixelSize: Cove.fontSizeSmall
                        Layout.leftMargin: 18
                    }
                    KIcon {
                        visible: !!it.modelData.more
                        icon: "chevron_right"
                        size: 16
                        color: Cove.overlay1
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    enabled: !it.sep && it.ok
                    hoverEnabled: true
                    onClicked: {
                        const f = it.modelData.run;
                        if (!it.modelData.more) root.close();
                        if (f) f();
                    }
                }
            }
        }
    }
}
