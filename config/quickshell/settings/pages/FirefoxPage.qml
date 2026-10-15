import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: "Firefox"
    subtitle: I18n.tr("Вид браузера в стиле шелла. Цвета меняются вместе с обоями на лету, форма — после перезапуска Firefox.")

    readonly property var f: Settings.firefox

    readonly property var layouts: [
        { id: "floating", name: I18n.tr("Плавающий"), desc: I18n.tr("Адресная строка — капсула, страница — карточка") },
        { id: "oneline", name: I18n.tr("Одна строка"), desc: I18n.tr("Адрес и вкладки в одном ряду") },
        { id: "island", name: I18n.tr("Остров"), desc: I18n.tr("Адресная строка по центру, как остров") },
        { id: "vertical", name: I18n.tr("Вертикальные вкладки"), desc: I18n.tr("Колонка вкладок слева") },
        { id: "classic", name: I18n.tr("Классический"), desc: I18n.tr("Привычный Firefox, только стиль") }
    ]

    // миниатюра окна браузера в выбранном виде
    component Preview: Rectangle {
        id: pv
        property string kind
        readonly property bool card: kind !== "classic"
        implicitWidth: 232
        implicitHeight: 128
        radius: Theme.radiusSmall
        color: Theme.crust
        // вкладки сверху (кроме «одной строки» и вертикальных)
        Row {
            visible: pv.kind === "floating" || pv.kind === "island" || pv.kind === "classic"
            x: 8; y: 7; spacing: 4
            Repeater { model: 4; Rectangle { required property int index; width: 34; height: 9; radius: 4; color: index === 0 ? Theme.alpha(Theme.accent, 0.5) : Theme.surface0 } }
        }
        // вертикальные вкладки
        Column {
            visible: pv.kind === "vertical"
            x: 6; y: 8; spacing: 4
            Repeater { model: 6; Rectangle { required property int index; width: 12; height: 12; radius: 4; color: index === 0 ? Theme.alpha(Theme.accent, 0.5) : Theme.surface0 } }
        }
        // адресная строка
        Rectangle {
            readonly property real left: pv.kind === "vertical" ? 26 : 8
            x: pv.kind === "island" ? (pv.width - width) / 2 : left
            y: pv.kind === "oneline" ? 7 : pv.kind === "vertical" ? 8 : 22
            width: pv.kind === "island" ? 100 : pv.kind === "oneline" ? 90 : pv.width - left - 8
            height: pv.kind === "floating" || pv.kind === "vertical" ? 14 : 11
            radius: height / 2
            color: pv.kind === "island" ? Theme.mantle : Theme.surface0
            border.width: pv.kind === "floating" || pv.kind === "vertical" ? 1 : 0
            border.color: Theme.surface1
        }
        Row {
            visible: pv.kind === "oneline"
            x: 104; y: 8; spacing: 4
            Repeater { model: 3; Rectangle { required property int index; width: 34; height: 9; radius: 4; color: index === 0 ? Theme.alpha(Theme.accent, 0.5) : Theme.surface0 } }
        }
        // страница
        Rectangle {
            readonly property real top: pv.kind === "oneline" ? 24 : pv.kind === "vertical" ? 28 : pv.kind === "classic" ? 36 : 42
            x: pv.card ? (pv.kind === "vertical" ? 26 : 8) : 0
            y: top
            width: pv.width - x - (pv.card ? 8 : 0)
            height: pv.height - top - (pv.card ? 8 : 0)
            radius: pv.card ? 6 : 0
            color: Theme.base
            Column {
                x: 12; y: 12; spacing: 6
                Rectangle { width: 70; height: 5; radius: 2; color: Theme.surface1 }
                Rectangle { width: 120; height: 4; radius: 2; color: Theme.surface0 }
                Rectangle { width: 100; height: 4; radius: 2; color: Theme.surface0 }
            }
        }
    }

    SCard {
        title: I18n.tr("Вид")
        icon: "󰏘"
        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10
            Repeater {
                model: page.layouts
                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool active: page.f.layout === modelData.id
                    implicitWidth: 248
                    implicitHeight: 186
                    radius: Theme.radius
                    color: tm.containsMouse ? Theme.surface0 : Theme.mantle
                    border.width: active ? 2 : 1
                    border.color: active ? Theme.accent : tm.containsMouse ? Theme.surface2 : Theme.surface0
                    scale: tm.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    Preview { x: 8; y: 8; kind: tile.modelData.id }
                    StyledText { x: 12; y: 146; text: tile.modelData.name; font.bold: true; color: tile.active ? Theme.accent : Theme.text }
                    StyledText { x: 12; y: 164; width: parent.width - 24; text: tile.modelData.desc; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.f.layout = tile.modelData.id }
                }
            }
        }
        SRow {
            icon: "󰒓"
            title: I18n.tr("Меню и панели в стиле шелла")
            desc: I18n.tr("Контекстные меню, главное меню, загрузки, расширения — те же скругления и выделение")
            SSwitch { checked: page.f.menus; onToggled: v => page.f.menus = v }
        }
        SRow {
            icon: "󰋗"
            title: I18n.tr("Применяется после перезапуска Firefox")
            desc: I18n.tr("Цвета меняются сразу; форма (вид, меню) — при следующем запуске браузера")
            separator: false
        }
    }

    SCard {
        title: I18n.tr("Новая вкладка и стартовая страница")
        icon: "󰖟"
        SRow {
            icon: "󰃢"
            title: I18n.tr("Чистая новая вкладка")
            desc: I18n.tr("Только поиск и сайты: без рекламы, рекомендаций, погоды и виджетов")
            SSwitch { checked: page.f.cleanNewtab; onToggled: v => page.f.cleanNewtab = v }
        }
        SRow {
            icon: "󰋜"
            title: I18n.tr("Стартовая страница Cove")
            desc: I18n.tr("Домашняя страница в стиле дашборда: часы, приветствие, поиск с !-командами, сайты, размытые обои")
            SButton { text: I18n.tr("Открыть"); onClicked: Qt.openUrlExternally("file://" + FirefoxLook.startpagePath) }
            SSwitch { checked: page.f.startpage; onToggled: v => page.f.startpage = v }
        }
        SRow {
            visible: page.f.startpage
            icon: "󰍉"
            title: I18n.tr("Поисковик")
            SSegment {
                options: [
                    { value: "https://www.google.com/search?q=%s", label: "Google" },
                    { value: "https://yandex.ru/search/?text=%s", label: I18n.tr("Яндекс") },
                    { value: "https://duckduckgo.com/?q=%s", label: "DuckDuckGo" }
                ]
                current: page.f.engine
                onPicked: v => page.f.engine = v
            }
        }
        StyledText {
            visible: page.f.startpage
            Layout.leftMargin: 16
            Layout.topMargin: 6
            text: I18n.tr("Сайты на стартовой странице")
            color: Theme.subtext0
            font.pixelSize: Theme.fontSizeSmall
        }
        Repeater {
            model: page.f.startpage ? (page.f.links ?? []) : []
            RowLayout {
                id: linkRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                spacing: 8
                function set(k, v): void { const l = Settings.copy(page.f.links); l[index][k] = v; page.f.links = l; }
                SField { implicitWidth: 160; text: linkRow.modelData.name; onEdited: t => linkRow.set("name", t) }
                SField { Layout.fillWidth: true; text: linkRow.modelData.url; onEdited: t => linkRow.set("url", t) }
                IconButton { size: 30; iconSize: 14; icon: "delete"; iconColor: Theme.red
                    onClicked: { const l = Settings.copy(page.f.links); l.splice(linkRow.index, 1); page.f.links = l; } }
            }
        }
        SRow {
            visible: page.f.startpage
            icon: "󰐕"
            title: I18n.tr("Добавить сайт")
            separator: false
            SButton { icon: "󰐕"; text: I18n.tr("Добавить"); onClicked: page.f.links = [...Settings.copy(page.f.links ?? []), { name: I18n.tr("Сайт"), url: "https://" }] }
        }
    }
}
