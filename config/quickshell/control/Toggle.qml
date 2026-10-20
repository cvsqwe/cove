import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Плитка-переключатель центра управления. hasMore — стрелка для перехода на подстраницу.
// Вид — Оформление → Компоненты (Settings.appearance.tileStyle):
//   tiles — плитка со значком, названием и состоянием (две колонки);
//   round — круглая кнопка с подписью под ней (четыре колонки), подстраница — ПКМ;
//   list  — строка списка с состоянием справа (одна колонка).
// Включённое (tileOn): fill — заливка акцентом, tint — лёгкая подкраска, outline — обводка.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool on: false
    property bool hasMore: false

    signal clicked()
    signal more()

    readonly property string look: Settings.appearance.tileStyle ?? "tiles"
    readonly property string activeLook: Settings.appearance.tileOn ?? "fill"
    readonly property bool filled: on && activeLook === "fill"
    readonly property color fg: filled ? Theme.onAccent : Theme.text
    readonly property color iconColor: filled ? Theme.onAccent : on ? Theme.accent : look === "tiles" ? Theme.accent : Theme.subtext1
    readonly property color bgColor: filled ? Theme.accent
        : on && activeLook === "tint" ? Theme.alpha(Theme.accent, mouse.containsMouse ? 0.3 : 0.2)
        : mouse.containsMouse ? Theme.surface1 : Theme.surface0

    implicitHeight: look === "round" ? round.implicitHeight : Math.round((look === "list" ? 46 : 62) * Theme.density)
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    // ---- плитка / строка ----
    Rectangle {
        anchors.fill: parent
        visible: root.look !== "round"
        radius: root.look === "list" ? Theme.radiusSmall + 4 : Theme.radius
        color: root.bgColor
        border.width: root.on && root.activeLook === "outline" ? 2 : 0
        border.color: Theme.accent
        Behavior on color { ColorAnimation { duration: Theme.anim } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: root.hasMore ? 4 : 10
            spacing: 10

            MIcon {
                icon: root.icon
                fill: root.on
                color: root.iconColor
                size: root.look === "list" ? 18 : 20
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: root.label
                    color: root.fg
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall + 1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== "" && root.look === "tiles"
                    text: root.sub
                    color: root.filled ? Theme.alpha(Theme.onAccent, 0.75) : Theme.overlay1
                    font.pixelSize: Theme.fontSizeSmall - 1
                    elide: Text.ElideRight
                }
            }
            // в списке состояние — справа
            StyledText {
                visible: root.look === "list" && root.sub !== ""
                Layout.maximumWidth: 180
                text: root.sub
                color: root.filled ? Theme.alpha(Theme.onAccent, 0.75) : Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
            Rectangle {
                visible: root.hasMore
                implicitWidth: 30
                implicitHeight: root.look === "list" ? 34 : 46
                radius: Theme.radiusSmall
                color: moreMouse.containsMouse ? Theme.alpha(root.filled ? Theme.onAccent : Theme.text, 0.12) : "transparent"
                MIcon { anchors.centerIn: parent; icon: "󰅂"; color: root.filled ? Theme.onAccent : Theme.overlay1 }
                MouseArea { id: moreMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.more() }
            }
        }
    }

    // ---- круглая кнопка ----
    Column {
        id: round
        visible: root.look === "round"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(54 * Theme.density)
            height: width
            radius: width / 2
            color: root.bgColor
            border.width: root.on && root.activeLook === "outline" ? 2 : 0
            border.color: Theme.accent
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            MIcon { anchors.centerIn: parent; icon: root.icon; fill: root.on; color: root.iconColor; size: 22 }
            // точка — у кнопки есть подстраница (ПКМ)
            Rectangle {
                visible: root.hasMore
                width: 6; height: 6; radius: 3
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                color: root.filled ? Theme.onAccent : Theme.overlay1
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width)
            text: root.label
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSmall - 1
            color: root.on ? Theme.text : Theme.subtext0
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: root.hasMore && root.look !== "round" ? 38 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => m.button === Qt.RightButton && root.hasMore ? root.more() : root.clicked()
    }
}
