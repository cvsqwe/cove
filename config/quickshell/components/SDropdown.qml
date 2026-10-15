import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

// Выпадающий список с поиском (для длинных списков: шрифты, приложения, темы).
// options: [{ value, label, icon?, group? }] или массив строк.
Rectangle {
    id: root

    property var options: []
    property var current
    property string placeholder: I18n.tr("Выбрать…")
    property bool searchable: options.length > 8
    property int popupWidth: Math.max(width, 280)
    signal picked(var value)
    function open(): void { popup.open(); }

    readonly property var norm: options.map(o => typeof o === "object" ? o : { value: o, label: String(o) })
    readonly property var cur: norm.find(o => o.value === current) ?? null

    implicitWidth: 240
    implicitHeight: 34
    radius: Theme.radiusSmall + 2
    color: mouse.containsMouse || popup.opened ? Theme.surface1 : Theme.surface0
    border.width: popup.opened ? 1 : 0
    border.color: Theme.accent

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        StyledText {
            Layout.fillWidth: true
            text: root.cur ? ((root.cur.icon ? root.cur.icon + "  " : "") + root.cur.label) : root.placeholder
            color: root.cur ? Theme.text : Theme.overlay1
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSizeSmall + 1
        }
        MIcon {
            icon: popup.opened ? "expand_less" : "expand_more"
            color: Theme.overlay1
            size: Theme.iconSize - 2
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.opened ? popup.close() : popup.open()
    }

    // место до краёв окна: не помещается вниз — открываемся вверх; высота — не больше свободного места
    // строка списка — 32 px; contentHeight в момент открытия ещё не посчитан (делегаты создаются лениво)
    readonly property real natural: (searchable ? 40 : 0) + norm.length * 32 + 16
    function measure(): void {
        const top = root.mapToItem(null, 0, 0).y;
        const below = (root.Window.height || 800) - top - root.height - 14;
        const above = top - 14;
        const want = Math.min(360, natural);
        popup.up = below < want && above > below;
        popup.height = Math.max(80, Math.min(want, popup.up ? above : below));
    }

    Popup {
        id: popup
        property bool up: false
        y: up ? -height - 6 : root.height + 6
        width: root.popupWidth
        padding: 8
        onAboutToShow: root.measure()
        onOpened: { search.text = ""; if (root.searchable) search.forceActiveFocus(); }

        background: Rectangle {
            radius: Theme.radius
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface1
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animFast } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast } }

        ColumnLayout {
            id: col
            anchors.fill: parent
            spacing: 6

            TextField {
                id: search
                visible: root.searchable
                Layout.fillWidth: true
                placeholderText: I18n.tr("Поиск…")
                placeholderTextColor: Theme.overlay0
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSizeSmall + 1
                background: Rectangle { radius: Theme.radiusSmall; color: Theme.surface0 }
                Keys.onEscapePressed: popup.close()
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: list.contentHeight > list.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.surface2 }
                    background: null
                }
                model: root.norm.filter(o => search.text === "" || String(o.label).toLowerCase().includes(search.text.toLowerCase()))
                section.property: "group"
                section.delegate: StyledText {
                    required property string section
                    text: section
                    color: Theme.accent
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    topPadding: 8
                    bottomPadding: 4
                    leftPadding: 8
                }

                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 32
                    radius: Theme.radiusSmall
                    color: hov.containsMouse ? Theme.surface0 : modelData.value === root.current ? Theme.alpha(Theme.accent, 0.15) : "transparent"

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        width: parent.width - 20
                        text: (modelData.icon ? modelData.icon + "  " : "") + modelData.label
                        color: modelData.value === root.current ? Theme.accent : Theme.text
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.family: modelData.font ?? Theme.font
                    }
                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.picked(parent.modelData.value); popup.close(); }
                    }
                }
            }
        }
    }
}
