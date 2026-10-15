import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Воркспейсы. Стиль — Settings.bar.workspaceStyle:
// pills | dots | lines | squares | numbers | kanji | roman | icons (значок приложения на воркспейсе).
// workspaceOccupiedOnly — только занятые и текущий; workspaceActive — accent | text.
Rectangle {
    id: root

    readonly property var b: Settings.bar
    readonly property string style: b.workspaceStyle
    readonly property bool textual: ["numbers", "kanji", "roman"].includes(style)
    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property color activeColor: b.workspaceActive === "text" ? Theme.text : Theme.accent

    readonly property var kanji: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    readonly property var roman: ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

    function ws(id: int): var { return Hyprland.workspaces.values.find(w => w.id === id) ?? null; }
    function occupied(id: int): bool { const w = ws(id); return !!w && w.toplevels.values.length > 0; }
    function label(id: int): string { return style === "kanji" ? kanji[id - 1] ?? id : style === "roman" ? roman[id - 1] ?? id : String(id); }
    // значок первого приложения на воркспейсе
    function appIcon(id: int): string {
        const w = ws(id);
        const t = w?.toplevels.values[0];
        if (!t) return "";
        const app = t.wayland?.appId || t.lastIpcObject?.class || "";
        const e = app ? DesktopEntries.heuristicLookup(app) : null;
        return Quickshell.iconPath(e?.icon ?? app, "application-x-executable");
    }

    readonly property var ids: {
        void Hyprland.workspaces.values.length;
        let max = b.workspaces;
        for (const w of Hyprland.workspaces.values) if (w.id > max && w.id <= 10) max = w.id;
        max = Math.max(max, activeId);
        const out = [];
        for (let i = 1; i <= max; i++) if (!b.workspaceOccupiedOnly || i === activeId || occupied(i)) out.push(i);
        return out;
    }

    implicitWidth: row.implicitWidth + (textual || style === "icons" ? 10 : 20)
    implicitHeight: Theme.capsuleHeight - 2
    color: "transparent"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.style === "lines" ? 4 : root.style === "squares" ? 5 : root.textual || root.style === "icons" ? 2 : 6

        Repeater {
            model: root.ids

            Item {
                id: cell
                required property int modelData
                readonly property int wsId: modelData
                readonly property bool active: wsId === root.activeId
                readonly property bool busy: root.occupied(wsId)
                readonly property bool hovered: hover.containsMouse

                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: root.style === "pills" ? (active ? 26 : 10)
                    : root.style === "dots" ? 8
                    : root.style === "lines" ? (active ? 22 : 10)
                    : root.style === "squares" ? 10
                    : root.style === "icons" ? 24
                    : Math.max(20, txt.implicitWidth + 10)
                implicitHeight: root.style === "lines" ? 3 : root.style === "dots" ? 8 : root.style === "pills" || root.style === "squares" ? 10 : 22
                Behavior on implicitWidth { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
                opacity: hovered && !active ? 0.7 : 1

                // фигуры: капли, точки, линии, квадраты
                Rectangle {
                    anchors.fill: parent
                    visible: !root.textual && root.style !== "icons"
                    radius: root.style === "squares" ? 3 : height / 2
                    color: cell.active ? root.activeColor
                        : root.style === "squares" && !cell.busy ? "transparent"
                        : cell.busy ? Theme.overlay1 : Theme.surface2
                    border.width: root.style === "squares" && !cell.active && !cell.busy ? 1.5 : 0
                    border.color: Theme.surface2
                    Behavior on color { ColorAnimation { duration: Theme.anim } }
                }

                // цифры, кандзи, римские
                Rectangle {
                    anchors.fill: parent
                    visible: root.textual
                    radius: Theme.barRound ? height / 2 : Theme.radiusSmall
                    color: cell.active ? root.activeColor : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.anim } }
                }
                Text {
                    id: txt
                    anchors.centerIn: parent
                    visible: root.textual
                    text: root.label(cell.wsId)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: cell.active
                    color: cell.active ? Theme.onAccent : cell.busy ? Theme.text : Theme.overlay0
                }

                // значки приложений
                Rectangle {
                    anchors.fill: parent
                    visible: root.style === "icons" && cell.active
                    radius: Theme.barRound ? height / 2 : Theme.radiusSmall
                    color: Theme.capsuleHover
                }
                IconImage {
                    anchors.centerIn: parent
                    visible: root.style === "icons" && cell.busy
                    implicitSize: 16
                    source: root.style === "icons" && cell.busy ? root.appIcon(cell.wsId) : ""
                    layer.enabled: !cell.active
                    layer.effect: MultiEffect { saturation: -0.9; opacity: 0.75 }
                }
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.style === "icons" && !cell.busy
                    width: 5; height: 5; radius: 2.5
                    color: cell.active ? root.activeColor : Theme.surface2
                }
                Rectangle {   // метка активного под значком
                    visible: root.style === "icons" && cell.active && cell.busy
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 8; height: 2; radius: 1
                    color: root.activeColor
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(cell.wsId)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => {
            const next = root.activeId + (w.angleDelta.y < 0 ? 1 : -1);
            if (next >= 1 && next <= 10) Hypr.focusWorkspace(next);
        }
    }
}
