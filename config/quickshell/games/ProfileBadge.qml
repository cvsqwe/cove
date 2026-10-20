import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Профиль на витрине: уровень в кольце (цвет рамки растёт с уровнем), звание, полоса опыта.
RowLayout {
    id: root
    spacing: 12

    Item {
        implicitWidth: 52
        implicitHeight: 52
        RingArc {
            anchors.fill: parent
            thickness: 4
            value: Profile.levelProgress
            color: Profile.frameOf(Profile.level)
        }
        StyledText {
            anchors.centerIn: parent
            text: Profile.level
            font.pixelSize: 20
            font.bold: true
            color: Profile.frameOf(Profile.level)
        }
    }
    ColumnLayout {
        spacing: 2
        StyledText { text: Profile.title; font.bold: true }
        StyledText {
            text: Profile.level >= Profile.maxLevel ? I18n.tr("Максимальный уровень")
                : (Profile.xp - Profile.xpAt(Profile.level)) + " / " + (Profile.xpAt(Profile.level + 1) - Profile.xpAt(Profile.level)) + I18n.tr(" опыта")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
        }
        Rectangle {
            implicitWidth: 150
            implicitHeight: 5
            radius: 3
            color: Theme.surface0
            Rectangle {
                width: parent.width * Profile.levelProgress
                height: parent.height
                radius: 3
                color: Profile.frameOf(Profile.level)
                Behavior on width { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
            }
        }
    }
}
