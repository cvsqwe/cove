import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

// Страница настроек: заголовок + прокручиваемая колонка карточек.
Flickable {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: col.data

    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 48
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    ColumnLayout {
        id: col
        x: 28
        y: 24
        width: root.width - 56
        spacing: 22

        ColumnLayout {
            spacing: 4
            StyledText { text: root.title; font.pixelSize: 26; font.bold: true }
            StyledText { visible: root.subtitle !== ""; text: root.subtitle; color: Theme.overlay1; Layout.fillWidth: true; wrapMode: Text.Wrap }
        }
    }
}
