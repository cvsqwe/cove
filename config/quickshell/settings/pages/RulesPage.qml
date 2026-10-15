import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Правила окон")
    subtitle: I18n.tr("Куда и как открывать конкретные приложения: на нужный воркспейс, плавающим, поверх всех, прозрачным…")

    readonly property var openClasses: [...new Set(Hyprland.toplevels.values.map(t => t.lastIpcObject?.class).filter(Boolean))].sort()

    function update(i: int, k: string, v): void {
        const l = Settings.copy(Settings.rules);
        l[i][k] = v;
        Settings.rules = l;
    }
    function add(cls: string): void {
        Settings.rules = [...Settings.copy(Settings.rules ?? []), {
            matchBy: "class", value: cls, exact: true, enabled: true,
            workspace: "", silent: false, float: false, size: "", center: false, pin: false,
            fullscreen: false, maximize: false, opacity: 1, noBlur: false, noAnim: false, idleInhibit: false
        }];
    }
    function remove(i: int): void { const l = Settings.copy(Settings.rules); l.splice(i, 1); Settings.rules = l; }

    Component.onCompleted: Hyprland.refreshToplevels()

    SCard {
        title: I18n.tr("Новое правило")
        icon: "󰐕"
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 10
            SDropdown {
                Layout.preferredWidth: 280
                placeholder: I18n.tr("Выбрать из открытых окон")
                options: page.openClasses
                onPicked: v => page.add(v)
            }
            StyledText { text: I18n.tr("или"); color: Theme.overlay1 }
            SField { id: custom; Layout.fillWidth: true; placeholderText: I18n.tr("класс окна, например org.telegram.desktop") }
            SButton { icon: "󰐕"; text: I18n.tr("Добавить"); primary: true; enabled_: custom.text.trim() !== ""; onClicked: { page.add(custom.text.trim()); custom.text = ""; } }
        }
    }

    StyledText {
        visible: (Settings.rules ?? []).length === 0
        text: I18n.tr("Правил пока нет. Например: Telegram всегда на 3-м воркспейсе, mpv — плавающим поверх всех.")
        color: Theme.overlay0
        Layout.fillWidth: true
        wrapMode: Text.Wrap
    }

    Repeater {
        model: Settings.rules ?? []

        SCard {
            id: rc
            required property var modelData
            required property int index
            title: modelData.value
            icon: "󰖯"

            SRow {
                icon: "󰒓"
                title: I18n.tr("Правило включено")
                SButton { icon: "󰆴"; text: I18n.tr("Удалить"); danger: true; onClicked: page.remove(rc.index) }
                SSwitch { checked: rc.modelData.enabled !== false; onToggled: v => page.update(rc.index, "enabled", v) }
            }
            SRow {
                icon: "󰍉"
                title: I18n.tr("Совпадение")
                SSegment {
                    options: [{ value: "class", label: I18n.tr("Класс") }, { value: "title", label: I18n.tr("Заголовок") }]
                    current: rc.modelData.matchBy
                    onPicked: v => page.update(rc.index, "matchBy", v)
                }
                SField { implicitWidth: 220; text: rc.modelData.value; onEdited: t => page.update(rc.index, "value", t) }
            }
            SRow {
                icon: "󰍹"
                title: I18n.tr("Воркспейс")
                SDropdown {
                    implicitWidth: 150
                    options: [{ value: "", label: I18n.tr("любой") }, ...Array.from({ length: 10 }, (_, i) => ({ value: String(i + 1), label: I18n.tr("Воркспейс ") + (i + 1) })), { value: "special:magic", label: I18n.tr("Скрытый") }]
                    current: rc.modelData.workspace ?? ""
                    onPicked: v => page.update(rc.index, "workspace", v)
                }
                StyledText { visible: !!rc.modelData.workspace; text: I18n.tr("не переходить"); color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                SSwitch { visible: !!rc.modelData.workspace; checked: !!rc.modelData.silent; onToggled: v => page.update(rc.index, "silent", v) }
            }
            SRow {
                icon: "󰖲"
                title: I18n.tr("Плавающее окно")
                SDropdown {
                    visible: !!rc.modelData.float
                    implicitWidth: 150
                    options: [{ value: "", label: I18n.tr("Свой размер") }, "800 600", "1000 700", "1200 800", "1400 900", "600 900"]
                    current: rc.modelData.size ?? ""
                    onPicked: v => page.update(rc.index, "size", v)
                }
                SSwitch { checked: !!rc.modelData.float; onToggled: v => page.update(rc.index, "float", v) }
            }
            SRow {
                title: I18n.tr("По центру · Поверх всех · На весь экран · Развернуть")
                icon: "󰘞"
                Repeater {
                    model: [["center", "󰘞"], ["pin", "󰐃"], ["fullscreen", "󰊓"], ["maximize", "󰁌"]]
                    IconButton {
                        required property var modelData
                        icon: modelData[1]
                        active: !!rc.modelData[modelData[0]]
                        onClicked: page.update(rc.index, modelData[0], !rc.modelData[modelData[0]])
                    }
                }
            }
            SRow {
                icon: "󰃝"
                title: I18n.tr("Прозрачность")
                SSlider { from: 0.3; to: 1; step: 0.05; value: rc.modelData.opacity ?? 1; percent: true; onMoved: v => page.update(rc.index, "opacity", v) }
            }
            SRow {
                icon: "󰂵"
                title: I18n.tr("Без размытия · Без анимаций · Не гасить экран")
                separator: false
                Repeater {
                    model: [["noBlur", "󰂵"], ["noAnim", "󰑮"], ["idleInhibit", "󰅶"]]
                    IconButton {
                        required property var modelData
                        icon: modelData[1]
                        active: !!rc.modelData[modelData[0]]
                        onClicked: page.update(rc.index, modelData[0], !rc.modelData[modelData[0]])
                    }
                }
            }
        }
    }
}
