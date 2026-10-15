import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components

// Календарь на месяц, неделя с понедельника. Колесо/стрелки листают месяцы.
Card {
    id: card
    implicitWidth: 260

    property int offset: 0 // сдвиг от текущего месяца

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    readonly property date today: clock.date
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var cells: {
        const first = (month.getDay() + 6) % 7; // пн = 0
        const start = new Date(month.getFullYear(), month.getMonth(), 1 - first);
        return Array.from({ length: 42 }, (_, i) => new Date(start.getFullYear(), start.getMonth(), start.getDate() + i));
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: {
                    const s = I18n.locale.standaloneMonthName(card.month.getMonth());
                    return s.charAt(0).toUpperCase() + s.slice(1) + " " + card.month.getFullYear();
                }
                font.bold: true
            }
            MIcon {
                icon: "󰅁"
                color: prev.containsMouse ? Theme.accent : Theme.overlay1
                MouseArea { id: prev; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: card.offset-- }
            }
            MIcon {
                icon: "󰅂"
                color: next.containsMouse ? Theme.accent : Theme.overlay1
                MouseArea { id: next; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; onClicked: card.offset++ }
            }
        }

        GridLayout {
            columns: 7
            columnSpacing: 2
            rowSpacing: 1

            Repeater {
                model: [I18n.tr("пн"), I18n.tr("вт"), I18n.tr("ср"), I18n.tr("чт"), I18n.tr("пт"), I18n.tr("сб"), I18n.tr("вс")]
                StyledText {
                    required property string modelData
                    required property int index
                    Layout.preferredWidth: 32
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: index >= 5 ? Theme.red : Theme.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Repeater {
                model: card.cells

                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isToday: modelData.toDateString() === card.today.toDateString()
                    readonly property bool inMonth: modelData.getMonth() === card.month.getMonth()

                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 26
                    radius: Theme.radiusSmall
                    color: isToday ? Theme.accent : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.getDate()
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.bold: parent.isToday
                        color: parent.isToday ? Theme.crust
                            : !parent.inMonth ? Theme.surface2
                            : index % 7 >= 5 ? Theme.red
                            : Theme.text
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: w => card.offset += w.angleDelta.y > 0 ? -1 : 1
    }
}
