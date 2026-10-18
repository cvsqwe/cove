import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Профили")
    subtitle: I18n.tr("Готовые стили и ваши собственные. Профиль запоминает оформление, панель, остров, окна и обои.")

    component ProfileCard: Rectangle {
        id: card
        property string name
        property var p
        property bool custom: false

        implicitWidth: 250
        implicitHeight: 150
        radius: Theme.radius
        color: hov.containsMouse ? Theme.surface0 : Theme.mantle
        border.width: 1
        border.color: hov.containsMouse ? Theme.accent : Theme.surface0
        scale: hov.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        // полоса с цветом пресета
        Rectangle {
            width: parent.width
            height: 46
            topLeftRadius: parent.radius
            topRightRadius: parent.radius
            color: card.p?.appearance?.customAccent ?? (card.p?.appearance?.light ? "#eff1f5" : Theme.accent)
            opacity: 0.85
            Image {
                anchors.fill: parent
                visible: !!card.p?.wallpaper
                source: card.p?.wallpaper ? "file://" + card.p.wallpaper : ""
                sourceSize: Qt.size(260, 60)
                fillMode: Image.PreserveAspectCrop
            }
            MIcon {
                anchors.centerIn: parent
                icon: card.p?.icon ?? "󰏘"
                size: 24
                color: card.p?.appearance?.light ? "#4c4f69" : Theme.crust
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 56
            spacing: 2
            StyledText { text: card.name; font.bold: true }
            StyledText {
                Layout.fillWidth: true
                text: card.p?.desc ?? ""
                color: Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Profiles.apply(card.p)
        }

        IconButton {
            visible: card.custom
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            size: 28
            iconSize: 13
            icon: "󰆴"
            iconColor: Theme.red
            onClicked: Profiles.remove(card.name)
        }
    }

    SCard {
        title: I18n.tr("Сохранить текущий вид")
        icon: "󰆓"
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 10
            SField { id: name; Layout.fillWidth: true; placeholderText: I18n.tr("Название, например «Работа»") }
            SButton {
                icon: "󰆓"
                text: I18n.tr("Сохранить")
                primary: true
                enabled_: name.text.trim() !== ""
                onClicked: { Profiles.save(name.text.trim()); name.text = ""; }
            }
        }
        SRow {
            icon: "ios_share"
            title: I18n.tr("Файл профиля")
            desc: I18n.tr("Один файл .cove.json с оформлением, панелью, островом, окнами, терминалом и обоями — для другого компьютера или друга")
            separator: false
            SButton { icon: "upload"; text: I18n.tr("Экспорт текущего"); onClicked: Profiles.exportProfile(name.text.trim()) }
            SButton { icon: "download"; text: I18n.tr("Импорт"); onClicked: Profiles.importProfile() }
        }
    }

    StyledText { text: I18n.tr("Мои профили"); font.bold: true; color: Theme.subtext1; visible: Object.keys(Settings.profiles ?? {}).length > 0 }
    Flow {
        Layout.fillWidth: true
        spacing: 14
        visible: Object.keys(Settings.profiles ?? {}).length > 0
        Repeater {
            model: Object.keys(Settings.profiles ?? {})
            ProfileCard { required property string modelData; name: modelData; p: Settings.profiles[modelData]; custom: true }
        }
    }

    StyledText { text: I18n.tr("Готовые стили — нажмите, чтобы примерить"); font.bold: true; color: Theme.subtext1 }
    Flow {
        Layout.fillWidth: true
        spacing: 14
        Repeater {
            model: Object.keys(Profiles.presets)
            ProfileCard { required property string modelData; name: modelData; p: Profiles.presets[modelData] }
        }
    }
}
