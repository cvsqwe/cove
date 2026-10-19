import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: "VPN"
    subtitle: I18n.tr("Свой VPN на ядре Mihomo (то же, что внутри Prizrak-Box и Clash): подписки, выбор сервера, российские сайты напрямую. Включается в центре управления.")

    readonly property var v: Settings.vpn
    Component.onCompleted: Vpn.probe()

    function nameFor(src: string): string {
        if (/^https?:\/\//.test(src)) { const m = src.match(/^https?:\/\/(?:sub\.)?([^/:]+)/); return m ? m[1] : "VPN"; }
        return src.split("/").pop().replace(/\.ya?ml$/, "");
    }
    function addFromField(): void {
        const t = add.text.trim();
        if (!t) return;
        Vpn.addSource(/^https?:\/\//.test(t) ? { name: nameFor(t), url: t } : { name: nameFor(t), path: t });
        add.text = "";
    }

    SCard {
        title: I18n.tr("Установка")
        icon: "build"
        SRow {
            icon: Vpn.hasCore ? "check_circle" : "download"
            title: I18n.tr("Ядро Mihomo")
            desc: Vpn.hasCore ? I18n.tr("Стоит") : I18n.tr("Пакет mihomo-bin из AUR — откроется терминал, пароль спросит yay")
            SButton { visible: !Vpn.hasCore; text: I18n.tr("Поставить"); primary: true; onClicked: Vpn.installCore() }
        }
        SRow {
            icon: Vpn.hasUnit ? "check_circle" : "shield"
            title: I18n.tr("Служба VPN")
            desc: Vpn.hasUnit ? I18n.tr("Стоит: VPN включается без пароля")
                : I18n.tr("Один раз, через окно прав администратора. Ядро работает от вашего имени, root ему не нужен")
            separator: false
            SButton {
                visible: !Vpn.hasUnit
                text: Vpn.installing ? I18n.tr("Ставлю…") : I18n.tr("Поставить")
                primary: Vpn.hasCore
                enabled_: Vpn.hasCore && !Vpn.installing
                onClicked: Vpn.installService()
            }
        }
    }

    SCard {
        title: I18n.tr("Подписки")
        icon: "link"

        Repeater {
            model: page.v.sources ?? []
            SRow {
                required property var modelData
                required property int index
                icon: modelData.url ? "cloud_sync" : "description"
                title: modelData.name
                // ссылка подписки — ключ доступа: показываем только адрес сервера
                desc: modelData.url ? modelData.url.replace(/^(https?:\/\/[^/]+).*/, "$1/…") : modelData.path
                SSwitch { checked: modelData.enabled !== false; onToggled: on => Vpn.setSource(index, { enabled: on }) }
                IconButton { size: 30; iconSize: 15; icon: "delete"; onClicked: Vpn.removeSource(index) }
            }
        }
        SRow {
            icon: "add_link"
            title: I18n.tr("Добавить")
            desc: I18n.tr("Ссылка на подписку (vless, vmess, trojan, ss, hysteria — любой формат) или путь к профилю Clash YAML")
            separator: Vpn.found.length > 0
            SField { id: add; implicitWidth: 300; placeholderText: "https://…"; onAccepted: page.addFromField() }
            SButton { text: I18n.tr("Добавить"); primary: true; onClicked: page.addFromField() }
        }
        Repeater {
            model: Vpn.found
            SRow {
                required property var modelData
                icon: "move_down"
                title: modelData.name
                desc: I18n.tr("из Prizrak-Box")
                SButton { text: I18n.tr("Взять"); onClicked: Vpn.addSource(modelData) }
            }
        }
        SRow {
            icon: "move_down"
            title: I18n.tr("Перенести из Prizrak-Box")
            desc: I18n.tr("Найдёт ваши подписки в ~/Prizrak-Box-V3")
            separator: false
            SButton { text: I18n.tr("Найти"); onClicked: Vpn.scanPrizrak() }
        }
    }

    SCard {
        title: I18n.tr("Подключение")
        icon: "vpn_lock"
        SRow {
            icon: "route"
            title: I18n.tr("Что пускать через VPN")
            desc: page.v.route === "ru" ? I18n.tr("Российские сайты (.ru, .рф, адреса в России) — напрямую, остальное через VPN")
                : I18n.tr("Весь трафик через VPN")
            SSegment {
                options: [{ value: "ru", label: I18n.tr("Кроме РФ") }, { value: "all", label: I18n.tr("Всё") }]
                current: page.v.route
                onPicked: val => page.v.route = val
            }
        }
        SRow {
            icon: "alt_route"
            title: I18n.tr("Всегда напрямую")
            desc: I18n.tr("Свои сайты мимо VPN, через запятую: bank.com, work.local")
            SField {
                implicitWidth: 260
                text: (page.v.direct ?? []).join(", ")
                placeholderText: "example.com"
                onEdited: t => page.v.direct = t.split(",").map(x => x.trim()).filter(x => x)
            }
        }
        SRow {
            icon: "power_settings_new"
            title: I18n.tr("Подключаться при входе")
            SSwitch { checked: page.v.autoConnect; onToggled: val => page.v.autoConnect = val }
        }
        SRow {
            icon: "lan"
            title: I18n.tr("Прокси для программ")
            desc: I18n.tr("Работает весь трафик системы. Для программ, которым нужен именно прокси: HTTP/SOCKS 127.0.0.1:7897")
            separator: false
        }
    }

    SCard {
        title: I18n.tr("Если не работает")
        icon: "help"
        SRow {
            icon: "receipt_long"
            title: I18n.tr("Журнал ядра")
            desc: Vpn.error || I18n.tr("Сообщения Mihomo: почему не подключается, какой сервер не отвечает")
            separator: false
            SButton {
                text: I18n.tr("Открыть")
                onClicked: Quickshell.execDetached([Settings.general.terminal, "-e", "journalctl", "-fu", Vpn.unit])
            }
        }
    }
}
