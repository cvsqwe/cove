import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Дотфайлы")
    subtitle: I18n.tr("Снимки ваших конфигов в git. После переустановки системы — скопировать обратно, и всё как было.")

    Component.onCompleted: Dotfiles.refreshLog()

    SCard {
        title: I18n.tr("Репозиторий")
        icon: "󰊢"
        SRow {
            icon: "󰉋"
            title: I18n.tr("Папка")
            SField { implicitWidth: 280; text: Settings.dotfiles.repo; onEdited: t => Settings.dotfiles.repo = t }
        }
        SRow {
            icon: "󰒍"
            title: I18n.tr("Удалённый репозиторий")
            desc: I18n.tr("Необязательно. Например git@github.com:you/dotfiles.git")
            SField { implicitWidth: 280; text: Settings.dotfiles.remote; placeholderText: "git@github.com:…"; onEdited: t => Settings.dotfiles.remote = t }
        }
        SRow {
            icon: "󰆓"
            title: I18n.tr("Что сохраняется")
            desc: Dotfiles.paths.map(p => "~/" + p).join(", ")
            separator: false
        }
    }

    RowLayout {
        spacing: 10
        SButton { icon: "󰆓"; text: Dotfiles.busy ? I18n.tr("Работаю…") : I18n.tr("Сделать снимок"); primary: true; enabled_: !Dotfiles.busy; onClicked: Dotfiles.snapshot() }
        SButton { icon: "󰕒"; text: I18n.tr("Отправить"); enabled_: !Dotfiles.busy && Settings.dotfiles.remote !== ""; onClicked: Dotfiles.push() }
    }

    Rectangle {
        visible: Dotfiles.output !== ""
        Layout.fillWidth: true
        implicitHeight: out.implicitHeight + 24
        radius: Theme.radius
        color: Theme.crust
        StyledText {
            id: out
            anchors.fill: parent
            anchors.margins: 12
            text: Dotfiles.output.trim()
            color: Theme.subtext0
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }
    }

    SCard {
        title: I18n.tr("История")
        icon: "󰋚"
        StyledText {
            visible: Dotfiles.log.length === 0
            Layout.margins: 16
            text: I18n.tr("Снимков ещё не было.")
            color: Theme.overlay0
        }
        Repeater {
            model: Dotfiles.log
            SRow {
                required property var modelData
                required property int index
                icon: "󰜘"
                title: modelData.subject
                desc: modelData.hash + " · " + modelData.time
                separator: index < Dotfiles.log.length - 1
            }
        }
    }
}
