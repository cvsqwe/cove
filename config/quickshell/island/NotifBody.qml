import QtQuick
import qs.config
import qs.components
import qs.services

// Уведомление, выпавшее из острова. ЛКМ — действие по умолчанию, ПКМ — закрыть.
Item {
    id: root

    property bool shown: false
    // держим последнее уведомление, чтобы оно не исчезало посреди анимации сворачивания
    property var shownNotif: null
    readonly property var n: Notifs.current ?? shownNotif
    onNChanged: if (Notifs.current) shownNotif = Notifs.current

    implicitHeight: item.implicitHeight
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    NotifItem {
        id: item
        width: parent.width
        notification: root.n
        // вид — Оформление → Компоненты: compact — одна строка, rich — подробно
        readonly property string look: Settings.appearance.notifStyle ?? "normal"
        compact: look === "compact"
        bodyLines: look === "compact" ? 1 : look === "rich" ? 6 : 3
        canReply: false
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (!root.n) return;
            if (m.button === Qt.RightButton) { root.n.dismiss(); return; }
            const def = root.n.actions.find(a => a.identifier === "default");
            if (def) def.invoke();
            Notifs.next();
        }
    }
}
