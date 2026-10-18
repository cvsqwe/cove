import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Заголовок активного окна. Для Cove Code — проект, файл, ветка и проблемы (services/CoveCode.qml).
Item {
    id: root
    property real maxWidth: 400
    readonly property var win: Hyprland.activeToplevel
    readonly property bool onCurrent: !!win && !!win.workspace && win.workspace.id === Hyprland.focusedWorkspace?.id
    readonly property bool cove: onCurrent && CoveCode.active
    readonly property var s: CoveCode.status

    visible: cove || title.text !== ""
    implicitWidth: Math.min(cove ? coveRow.implicitWidth + 24 : title.implicitWidth, maxWidth)
    implicitHeight: Theme.capsuleHeight
    width: implicitWidth
    clip: true

    StyledText {
        id: title
        visible: !root.cove
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.maxWidth)
        leftPadding: 12
        rightPadding: 12
        text: root.onCurrent ? root.win.title : ""
        color: Theme.subtext1
        elide: Text.ElideRight
    }

    Row {
        id: coveRow
        visible: root.cove
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "cove"; size: Theme.fontSize; color: Theme.accent }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.s?.project ?? ""
            color: Theme.text
            font.bold: true
        }
        StyledText {
            visible: (root.s?.file ?? "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: "/ " + (root.s?.file ?? "") + ((root.s?.modified ?? 0) > 0 ? " ●" : "")
            color: Theme.subtext1
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, root.maxWidth * 0.45)
        }
        Rectangle {
            visible: (root.s?.branch ?? "") !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: branchRow.implicitWidth + 12
            height: 18
            radius: 9
            color: Theme.alpha(Theme.accent2, 0.16)
            Row {
                id: branchRow
                anchors.centerIn: parent
                spacing: 3
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "fork_right"; size: Theme.fontSizeSmall; color: Theme.accent2 }
                StyledText { anchors.verticalCenter: parent.verticalCenter; text: root.s?.branch ?? ""; color: Theme.accent2; font.pixelSize: Theme.fontSizeSmall }
            }
        }
        Row {
            visible: (root.s?.errors ?? 0) > 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "error"; fill: true; size: Theme.fontSizeSmall; color: Theme.red }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: root.s?.errors ?? 0; color: Theme.red; font.pixelSize: Theme.fontSizeSmall }
        }
        Row {
            visible: (root.s?.warnings ?? 0) > 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "warning"; fill: true; size: Theme.fontSizeSmall; color: Theme.yellow }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: root.s?.warnings ?? 0; color: Theme.yellow; font.pixelSize: Theme.fontSizeSmall }
        }
    }
}
