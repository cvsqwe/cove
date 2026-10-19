import QtQuick
import QtQuick.Layouts
import qs.kit
import qs.services

// Строка пути: «хлебные крошки» (клик — перейти, на крошку можно бросить файлы),
// клик по пустому месту или Ctrl+L — ввести путь руками.
Rectangle {
    id: root
    property var pane: null
    property bool editing: false
    signal navigate(string path)
    signal dropped(var urls, string dest, int action)

    function edit(): void {
        editing = true;
        field.text = pane.mode === "dir" ? (pane.path === Cove.home ? "~" : pane.path.replace(Cove.home + "/", "~/")) : pane.path;
        field.input.forceActiveFocus();
        field.input.selectAll();
    }

    implicitHeight: 34
    radius: Cove.radiusSmall + 2
    color: Cove.mantle
    border.width: 1
    border.color: editing ? Cove.accent : "transparent"

    // сегменты пути от корня или от домашней папки
    readonly property var crumbs: {
        if (!pane) return [];
        if (pane.mode === "trash") return [{ label: "Корзина", path: "", icon: "delete" }];
        const p = pane.path, h = Cove.home;
        const out = [];
        let rest;
        if (p === h || p.startsWith(h + "/")) {
            out.push({ label: "Домашняя", path: h, icon: "home" });
            rest = p.slice(h.length);
        } else {
            out.push({ label: "", path: "/", icon: "computer" });
            rest = p === "/" ? "" : p;
        }
        let acc = out[0].path === "/" ? "" : h;
        for (const s of rest.split("/").filter(Boolean)) {
            acc += "/" + s;
            out.push({ label: s, path: acc, icon: "" });
        }
        if (pane.mode === "search") out.push({ label: "«" + pane.query + "»", path: "", icon: "search" });
        return out;
    }

    MouseArea {
        anchors.fill: parent
        visible: !root.editing
        cursorShape: Qt.IBeamCursor
        onClicked: root.edit()
    }

    Flickable {
        id: fl
        visible: !root.editing
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        contentWidth: row.implicitWidth
        clip: true
        interactive: contentWidth > width
        boundsBehavior: Flickable.StopAtBounds
        // всегда видно конец пути
        onContentWidthChanged: contentX = Math.max(0, contentWidth - width)
        onWidthChanged: contentX = Math.max(0, contentWidth - width)

        Row {
            id: row
            height: fl.height
            spacing: 0
            Repeater {
                model: root.crumbs
                Row {
                    id: cr
                    required property var modelData
                    required property int index
                    readonly property bool last: index === root.crumbs.length - 1
                    height: parent.height
                    KIcon {
                        visible: cr.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "chevron_right"
                        size: 15
                        color: Cove.overlay0
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        width: seg.implicitWidth + 16
                        radius: Cove.radiusSmall
                        color: drop.containsDrag ? Cove.alpha(Cove.accent, 0.3) : cm.containsMouse && cr.modelData.path ? Cove.surface0 : "transparent"
                        Row {
                            id: seg
                            anchors.centerIn: parent
                            spacing: 6
                            KIcon {
                                visible: cr.modelData.icon !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                icon: cr.modelData.icon
                                size: 15
                                color: cr.last ? Cove.accent : Cove.subtext0
                            }
                            KText {
                                visible: cr.modelData.label !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: cr.modelData.label
                                color: cr.last ? Cove.text : Cove.subtext0
                                font.bold: cr.last
                                elide: Text.ElideNone
                            }
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: cr.modelData.path ? Qt.PointingHandCursor : Qt.IBeamCursor
                            onClicked: cr.modelData.path ? root.navigate(cr.modelData.path) : root.edit()
                        }
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            enabled: cr.modelData.path !== "" && !cr.last
                            keys: ["text/uri-list"]
                            onDropped: e => { root.dropped(e.urls, cr.modelData.path, e.proposedAction); e.acceptProposedAction(); }
                        }
                    }
                }
            }
        }
    }

    // начало длинного пути уходит под затухание, а не обрезается посреди слова
    Rectangle {
        visible: !root.editing && fl.contentX > 1
        anchors.left: fl.left
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: parent.height - 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.color }
            GradientStop { position: 1; color: Cove.alpha(root.color, 0) }
        }
    }

    KField {
        id: field
        visible: root.editing
        anchors.fill: parent
        color: "transparent"
        border.width: 0
        icon: "folder_open"
        onAccepted: { root.editing = false; root.navigate(text.trim()); }
        onEscaped: root.editing = false
        input.onActiveFocusChanged: if (!input.activeFocus) root.editing = false
    }
}
