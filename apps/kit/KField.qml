import QtQuick

// Поле ввода
Rectangle {
    id: root
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    signal accepted()
    signal escaped()

    implicitHeight: 34
    implicitWidth: 220
    radius: Cove.radiusSmall + 2
    color: Cove.mantle
    border.width: 1
    border.color: input.activeFocus ? Cove.accent : Cove.surface0
    Behavior on border.color { ColorAnimation { duration: Cove.anim } }

    KIcon {
        id: ic
        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        size: 16
        color: Cove.overlay1
    }
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: root.icon !== "" ? 32 : 11
        anchors.rightMargin: 11
        verticalAlignment: TextInput.AlignVCenter
        color: Cove.text
        selectionColor: Cove.alpha(Cove.accent, 0.4)
        selectedTextColor: Cove.text
        font.family: Cove.font
        font.pixelSize: Cove.fontSize
        clip: true
        selectByMouse: true
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escaped()
        KText {
            anchors.fill: parent
            visible: !input.text && !input.preeditText
            text: root.placeholder
            color: Cove.overlay0
        }
    }
}
