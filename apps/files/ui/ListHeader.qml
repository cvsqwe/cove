import QtQuick
import QtQuick.Layouts
import qs.kit
import qs.services

// Шапка списка: клик по столбцу — сортировка, повторный — в обратную сторону
Rectangle {
    id: root
    property var items: null
    width: ListView.view ? ListView.view.width : 0
    height: items.headerH
    color: Cove.base

    function col(key: string): void {
        if (Prefs.sortBy === key) Prefs.sortDesc = !Prefs.sortDesc;
        else { Prefs.sortBy = key; Prefs.sortDesc = key === "mtime" || key === "size"; }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18 + 22 + 12
        anchors.rightMargin: 18
        spacing: 12
        H { Layout.fillWidth: true; label: "Имя"; key: "name" }
        H { Layout.preferredWidth: root.items.colDate; label: "Изменён"; key: "mtime" }
        H { Layout.preferredWidth: root.items.colSize; label: "Размер"; key: "size"; alignRight: true }
        H { Layout.preferredWidth: root.items.colType; label: "Тип"; key: "type" }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Cove.surface0 }

    component H: Item {
        id: h
        property string label
        property string key
        property bool alignRight: false
        readonly property bool active: Prefs.sortBy === key
        implicitHeight: 32
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: h.alignRight ? parent.right : undefined
            spacing: 2
            KText { text: h.label; color: h.active ? Cove.accent : Cove.overlay1; font.pixelSize: Cove.fontSizeSmall; font.bold: h.active }
            KIcon { visible: h.active; icon: Prefs.sortDesc ? "arrow_downward" : "arrow_upward"; size: 13; color: Cove.accent }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (Prefs.sortBy === h.key) Prefs.sortDesc = !Prefs.sortDesc;
                else { Prefs.sortBy = h.key; Prefs.sortDesc = h.key === "mtime" || h.key === "size"; }
            }
        }
    }
}
