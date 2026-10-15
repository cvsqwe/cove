import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Система")
    subtitle: I18n.tr("Вы, ваш город, приложения по умолчанию, сон и блокировка, ночной свет и фокус.")

    readonly property var g: Settings.general
    property var cityResults: []

    Process {
        id: geo
        property string q: ""
        command: ["curl", "-sf", "-m", "10", "https://geocoding-api.open-meteo.com/v1/search?count=6&language=ru&name=" + encodeURIComponent(q)]
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.cityResults = JSON.parse(text).results ?? []; } catch (e) { page.cityResults = []; }
            }
        }
    }

    SCard {
        title: I18n.tr("Вы")
        icon: "󰀄"
        SRow {
            icon: "󰗊"
            title: "Язык · Language"
            desc: I18n.tr("Интерфейс шелла, стартовая страница Firefox и терминал")
            SSegment {
                options: [
                    { value: "ru", label: "Русский" },
                    { value: "en", label: "English" },
                    { value: "auto", label: I18n.tr("Как в системе") }
                ]
                current: page.g.language
                onPicked: v => page.g.language = v
            }
        }
        SRow {
            icon: "󰀄"
            title: I18n.tr("Имя")
            desc: I18n.tr("Для приветствий. Пусто — имя пользователя (") + Quickshell.env("USER") + ")"
            SField { implicitWidth: 240; text: page.g.name; placeholderText: Quickshell.env("USER"); onEdited: t => page.g.name = t }
        }
        SRow {
            icon: "󰋩"
            title: I18n.tr("Аватар")
            desc: I18n.tr("Путь к картинке (квадратной). Показывается в центре управления и на экране блокировки")
            separator: false
            Rectangle {
                width: 34; height: 34; radius: 17
                color: Theme.accent
                clip: true
                Image { anchors.fill: parent; source: page.g.avatar ? "file://" + Settings.expand(page.g.avatar) : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(68, 68) }
            }
            SField { implicitWidth: 240; text: page.g.avatar; placeholderText: "~/Pictures/avatar.png"; onEdited: t => page.g.avatar = t }
        }
    }

    SCard {
        title: I18n.tr("Погода")
        icon: "󰖐"
        SRow {
            icon: "󰖐"
            title: I18n.tr("Показывать погоду и курсы")
            SSwitch { checked: page.g.weather; onToggled: v => { page.g.weather = v; Weather.refresh(); } }
        }
        SRow {
            icon: "󰍎"
            title: I18n.tr("Город")
            desc: `${page.g.city} (${page.g.latitude.toFixed(2)}, ${page.g.longitude.toFixed(2)})`
            separator: page.cityResults.length > 0
            SField {
                id: city
                implicitWidth: 240
                placeholderText: I18n.tr("Найти город…")
                onEdited: t => { if (t.trim()) { geo.q = t.trim(); geo.running = true; } }
            }
        }
        Repeater {
            model: page.cityResults
            SRow {
                required property var modelData
                required property int index
                icon: "󰋜"
                title: modelData.name
                desc: [modelData.admin1, modelData.country].filter(Boolean).join(", ")
                separator: index < page.cityResults.length - 1
                SButton {
                    text: I18n.tr("Выбрать")
                    onClicked: {
                        page.g.city = modelData.name;
                        page.g.latitude = modelData.latitude;
                        page.g.longitude = modelData.longitude;
                        city.text = "";
                        Qt.callLater(Weather.refresh);
                        // последним: очистка списка уничтожает эту строку вместе с обработчиком
                        page.cityResults = [];
                    }
                }
            }
        }
    }

    SCard {
        title: I18n.tr("Приложения по умолчанию")
        icon: "󰀻"
        Repeater {
            model: [
                { k: "terminal", icon: "", label: I18n.tr("Терминал"), ph: "kitty" },
                { k: "browser", icon: "󰖟", label: I18n.tr("Браузер"), ph: "firefox" },
                { k: "fileManager", icon: "󰉋", label: I18n.tr("Файловый менеджер"), ph: "kitty -e yazi" },
                { k: "editor", icon: "󰨞", label: I18n.tr("Редактор"), ph: "code" }
            ]
            SRow {
                required property var modelData
                required property int index
                icon: modelData.icon
                title: modelData.label
                separator: index < 3
                SField { implicitWidth: 260; text: page.g[modelData.k]; placeholderText: modelData.ph; onEdited: t => page.g[modelData.k] = t }
            }
        }
    }

    SCard {
        title: I18n.tr("Сон и блокировка")
        icon: "󰌾"
        SRow {
            icon: "󰌾"
            title: I18n.tr("Блокировать через")
            SSlider { from: 0; to: 60; step: 1; value: Settings.idle.lockMinutes; format: v => v === 0 ? I18n.tr("никогда") : v + I18n.tr(" мин"); onMoved: v => Settings.idle.lockMinutes = v }
        }
        SRow {
            icon: "󰶐"
            title: I18n.tr("Гасить экран через")
            SSlider { from: 0; to: 90; step: 1; value: Settings.idle.dpmsMinutes; format: v => v === 0 ? I18n.tr("никогда") : v + I18n.tr(" мин"); onMoved: v => Settings.idle.dpmsMinutes = v }
        }
        SRow {
            icon: "󰤄"
            title: I18n.tr("Засыпать через")
            separator: false
            SSlider { from: 0; to: 180; step: 5; value: Settings.idle.suspendMinutes; format: v => v === 0 ? I18n.tr("никогда") : v + I18n.tr(" мин"); onMoved: v => Settings.idle.suspendMinutes = v }
        }
    }

    SCard {
        title: I18n.tr("Ночной свет")
        icon: "󰖔"
        SRow {
            icon: "󰖔"
            title: I18n.tr("Включён")
            SSwitch { checked: Store.nightLight; onToggled: v => Store.nightLight = v }
        }
        SRow {
            icon: "󰔄"
            title: I18n.tr("Теплота")
            SSlider { from: 2500; to: 6000; step: 100; value: Settings.nightLight.temperature; suffix: " K"; onMoved: v => Settings.nightLight.temperature = v }
        }
        SRow {
            icon: "󰃰"
            title: I18n.tr("По расписанию")
            SSwitch { checked: Settings.nightLight.schedule; onToggled: v => Settings.nightLight.schedule = v }
        }
        SRow {
            visible: Settings.nightLight.schedule
            icon: "󱑆"
            title: I18n.tr("С и до")
            separator: false
            SField { implicitWidth: 80; text: Settings.nightLight.from; inputMask: "99:99"; onEdited: t => Settings.nightLight.from = t }
            StyledText { text: "—"; anchors.verticalCenter: parent.verticalCenter }
            SField { implicitWidth: 80; text: Settings.nightLight.to; inputMask: "99:99"; onEdited: t => Settings.nightLight.to = t }
        }
    }

    SCard {
        title: I18n.tr("Фокус-таймер")
        icon: "󰔟"
        SRow {
            icon: "󰔟"
            title: I18n.tr("Работа")
            SSlider { from: 5; to: 90; step: 5; value: Settings.focus.work; suffix: I18n.tr(" мин"); onMoved: v => Settings.focus.work = v }
        }
        SRow {
            icon: "󰅶"
            title: I18n.tr("Перерыв")
            SSlider { from: 1; to: 30; step: 1; value: Settings.focus.shortBreak; suffix: I18n.tr(" мин"); onMoved: v => Settings.focus.shortBreak = v }
        }
        SRow {
            icon: "󰂛"
            title: I18n.tr("«Не беспокоить» во время работы")
            separator: false
            SSwitch { checked: Settings.focus.dnd; onToggled: v => Settings.focus.dnd = v }
        }
    }
}
