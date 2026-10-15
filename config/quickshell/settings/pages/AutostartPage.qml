import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components

SPage {
    id: page
    title: I18n.tr("Автозапуск")
    subtitle: I18n.tr("Что запускать при входе в систему. Применится со следующего входа.")

    function set(list): void { Settings.autostart = list; }

    SCard {
        title: I18n.tr("Добавить")
        icon: "󰐕"
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 10
            SDropdown {
                Layout.preferredWidth: 280
                placeholder: I18n.tr("Приложение…")
                searchable: true
                options: DesktopEntries.applications.values.filter(e => !e.noDisplay)
                    .sort((x, y) => x.name.localeCompare(y.name))
                    .map(e => ({ value: e.id, label: e.name }))
                onPicked: v => {
                    const e = DesktopEntries.byId(v);
                    page.set([...Settings.copy(Settings.autostart ?? []), { name: e?.name ?? v, command: `gtk-launch ${v}`, enabled: true }]);
                }
            }
            StyledText { text: I18n.tr("или"); color: Theme.overlay1 }
            SField { id: cmd; Layout.fillWidth: true; placeholderText: I18n.tr("своя команда") }
            SButton {
                icon: "󰐕"; text: I18n.tr("Добавить"); primary: true
                enabled_: cmd.text.trim() !== ""
                onClicked: { page.set([...Settings.copy(Settings.autostart ?? []), { name: cmd.text.trim(), command: cmd.text.trim(), enabled: true }]); cmd.text = ""; }
            }
        }
    }

    SCard {
        title: I18n.tr("При входе")
        icon: "󰐊"
        StyledText {
            visible: (Settings.autostart ?? []).length === 0
            Layout.margins: 16
            text: I18n.tr("Пока пусто. Например, добавьте Telegram или Steam.")
            color: Theme.overlay0
        }
        Repeater {
            model: Settings.autostart ?? []
            SRow {
                required property var modelData
                required property int index
                icon: "󰐊"
                title: modelData.name
                desc: modelData.command
                separator: index < (Settings.autostart ?? []).length - 1
                IconButton { icon: "󰐊"; onClicked: Quickshell.execDetached(["sh", "-c", modelData.command]) }
                IconButton {
                    icon: "󰆴"; iconColor: Theme.red
                    onClicked: { const l = Settings.copy(Settings.autostart); l.splice(index, 1); page.set(l); }
                }
                SSwitch {
                    checked: modelData.enabled !== false
                    onToggled: v => { const l = Settings.copy(Settings.autostart); l[index].enabled = v; page.set(l); }
                }
            }
        }
    }
}
