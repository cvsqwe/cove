import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.desktop

SPage {
    id: page
    title: I18n.tr("Рабочий стол")
    subtitle: I18n.tr("Виджеты поверх обоев. Расставляются и настраиваются в редакторе прямо на рабочем столе.")

    readonly property var d: Settings.desktop
    function ipc(fn: string, arg: string): void { Quickshell.execDetached(arg ? ["qs", "ipc", "call", "desktop", fn, arg] : ["qs", "ipc", "call", "desktop", fn]); }
    function setWidget(i: int, k: string, v): void {
        const l = Settings.copy(page.d.widgets);
        l[i][k] = v;
        page.d.widgets = l;
    }
    function removeWidget(i: int): void {
        const l = Settings.copy(page.d.widgets);
        l.splice(i, 1);
        page.d.widgets = l;
    }

    SCard {
        title: I18n.tr("Виджеты")
        icon: "󰖲"
        SRow {
            icon: "󰖲"
            title: I18n.tr("Показывать виджеты")
            SSwitch { checked: page.d.enabled; onToggled: v => page.d.enabled = v }
        }
        SRow {
            icon: "󰆾"
            title: I18n.tr("Редактор")
            desc: I18n.tr("Перетаскивание, масштаб за уголок, свои настройки у каждого виджета. Можно назначить хоткей: действие «Редактор виджетов»")
            SButton { icon: "󰐕"; text: I18n.tr("Добавить"); onClicked: page.ipc("gallery", "") }
            SButton { icon: "󰆾"; text: I18n.tr("Открыть редактор"); primary: true; onClicked: page.ipc("edit", "") }
        }
        SRow {
            icon: "󰕰"
            title: I18n.tr("Привязка к сетке")
            separator: false
            SSwitch { checked: page.d.snap; onToggled: v => page.d.snap = v }
        }
    }

    SCard {
        title: I18n.tr("На рабочем столе")
        icon: "󰍹"
        Repeater {
            model: page.d.widgets
            SRow {
                required property var modelData
                required property int index
                readonly property var c: Catalog.types[modelData.type]
                icon: c?.icon ?? "?"
                title: c?.label ?? modelData.type
                desc: (c?.desc ?? "") + (modelData.scale && modelData.scale !== 1 ? ` · ${Math.round(modelData.scale * 100)}%` : "")
                separator: index < page.d.widgets.length - 1
                IconButton { size: 30; iconSize: 14; icon: "󰏫"; onClicked: page.ipc("select", modelData.id ?? "") }
                IconButton { size: 30; iconSize: 14; icon: "󰆴"; iconColor: Theme.red; onClicked: page.removeWidget(index) }
                SSwitch { checked: modelData.enabled !== false; onToggled: v => page.setWidget(index, "enabled", v) }
            }
        }
        StyledText {
            visible: page.d.widgets.length === 0
            Layout.margins: 16
            text: I18n.tr("Пусто — добавьте виджеты в редакторе")
            color: Theme.overlay0
        }
    }

    SCard {
        title: I18n.tr("Добавить")
        icon: "󰐕"
        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 8
            Repeater {
                model: Catalog.order
                SButton {
                    required property string modelData
                    icon: Catalog.types[modelData].icon
                    text: Catalog.types[modelData].label
                    onClicked: page.ipc("add", modelData)
                }
            }
        }
    }
}
