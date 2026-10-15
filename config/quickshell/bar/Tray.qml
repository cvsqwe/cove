import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.config
import qs.components

// Трей. В режиме «подписи при наведении» свёрнут в один значок и раскрывается под курсором.
Item {
    id: root

    required property var barWindow
    readonly property bool collapsible: Theme.barHoverLabels
    readonly property bool expanded: !collapsible || hover.hovered
    readonly property real size: Theme.capsuleHeight - 2

    visible: SystemTray.items.values.length > 0
    implicitHeight: size
    implicitWidth: expanded ? items.implicitWidth : size
    Behavior on implicitWidth { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
    clip: true

    HoverHandler { id: hover }

    // свёрнутый вид
    MIcon {
        anchors.centerIn: parent
        visible: opacity > 0
        opacity: root.expanded ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        icon: "more_horiz"
        color: Theme.barIcon
        size: Theme.iconSize
    }

  Row {
    id: items
    spacing: 0
    leftPadding: 2
    rightPadding: 2
    anchors.verticalCenter: parent.verticalCenter
    opacity: root.expanded ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: item
            required property SystemTrayItem modelData

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Theme.capsuleHeight - 2
            implicitHeight: Theme.capsuleHeight - 2
            radius: Theme.barRound ? height / 2 : Math.max(2, Theme.capsuleRadius - 2)
            color: mouse.containsMouse ? Theme.capsuleHover : "transparent"

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: item.modelData.icon
                layer.enabled: true
                layer.effect: MultiEffect { saturation: mouse.containsMouse ? 0 : -1; brightness: mouse.containsMouse ? 0 : -0.05 }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => {
                    const t = item.modelData;
                    if (m.button === Qt.RightButton || (m.button === Qt.LeftButton && t.onlyMenu)) {
                        if (t.hasMenu) {
                            const p = item.mapToItem(null, 0, item.height + 6);
                            t.display(root.barWindow, p.x, p.y);
                        }
                    } else if (m.button === Qt.MiddleButton) {
                        t.secondaryActivate();
                    } else {
                        t.activate();
                    }
                }
                onWheel: w => item.modelData.scroll(w.angleDelta.y, false)
            }
        }
    }
  }
}
