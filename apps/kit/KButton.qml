import QtQuick
import QtQuick.Layouts

// Кнопка: обычная, primary (акцент), danger или flat (без фона)
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    property bool flat: false
    property bool active: false
    property string tip: ""
    signal clicked()

    implicitWidth: text ? row.implicitWidth + 24 : 34
    implicitHeight: 34
    radius: Cove.radiusSmall + 2
    opacity: enabled ? 1 : 0.45
    color: primary ? (mouse.containsMouse ? Qt.lighter(Cove.accent, 1.08) : Cove.accent)
        : danger ? Cove.alpha(Cove.red, mouse.containsMouse ? 0.3 : 0.15)
        : active ? Cove.alpha(Cove.accent, mouse.containsMouse ? 0.28 : 0.2)
        : mouse.containsMouse ? Cove.surface1 : flat ? "transparent" : Cove.surface0
    scale: mouse.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Behavior on color { ColorAnimation { duration: Cove.anim } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 7
        KIcon {
            visible: root.icon !== ""
            icon: root.icon
            fill: root.active
            color: root.primary ? Cove.onAccent : root.danger ? Cove.red : root.active ? Cove.accent : Cove.subtext1
        }
        KText {
            visible: root.text !== ""
            text: root.text
            color: root.primary ? Cove.onAccent : root.danger ? Cove.red : Cove.text
            font.pixelSize: Cove.fontSizeSmall + 1
            font.bold: root.primary
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
    KTip { text: root.tip; shown: root.tip !== "" && mouse.containsMouse }
}
