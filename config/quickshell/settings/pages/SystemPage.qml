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
    readonly property var p: Settings.power
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
        title: I18n.tr("Питание")
        icon: "bolt"
        SRow {
            visible: Power.hasBattery
            icon: Power.icon()
            title: I18n.tr("Батарея {0}%", Power.percent)
            desc: Power.statusText
        }
        SRow {
            visible: Power.hasProfiles
            icon: Power.profileInfo(Power.profile).icon
            title: I18n.tr("Режим питания")
            desc: I18n.tr("Экономия — дольше от батареи, мощность — для игр и сборки")
            SSegment {
                options: Power.profiles.map(p => ({ value: p.value, label: p.label }))
                current: Power.profile
                onPicked: v => Power.setProfile(v)
            }
        }
        SRow {
            visible: Power.hasBattery && Power.hasProfiles
            icon: "energy_savings_leaf"
            title: I18n.tr("Экономия на низком заряде")
            desc: I18n.tr("От батареи на этом уровне и ниже. На зарядке вернётся прежний режим")
            SSlider {
                from: 0; to: 50; step: 5
                value: page.p.saverAt
                format: v => v > 0 ? v + "%" : I18n.tr("выкл")
                onMoved: v => page.p.saverAt = v
            }
        }
        SRow {
            icon: "brightness_medium"
            title: I18n.tr("Яркость экрана")
            desc: Power.kind === "ddc" ? I18n.tr("Монитор по DDC/CI (ddcutil)")
                : Power.kind === "backlight" ? I18n.tr("Подсветка экрана")
                : I18n.tr("Для обычного монитора поставьте ddcutil и включите DDC/CI в меню монитора")
            separator: false
            SSlider {
                visible: Power.hasBrightness
                from: 0.01; to: 1; step: 0.01; percent: true
                value: Power.brightness
                onMoved: v => Power.setBrightness(v)
            }
        }
    }

    SCard {
        title: I18n.tr("Сон и блокировка")
        icon: "󰌾"
        SRow {
            icon: "preview"
            title: I18n.tr("Экран блокировки")
            desc: I18n.tr("Посмотреть, как он выглядит, без блокировки")
            SButton { text: I18n.tr("Предпросмотр"); onClicked: Quickshell.execDetached(["qs", "ipc", "call", "lock", "preview"]) }
        }
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
        title: I18n.tr("Безопасность")
        icon: "admin_panel_settings"
        SRow {
            icon: "password"
            title: I18n.tr("Очищать скопированный пароль")
            desc: I18n.tr("Пароли из менеджера паролей не попадают в историю буфера и стираются через это время")
            SSlider { from: 0; to: 120; step: 5; value: page.g.clipClearSeconds; format: v => v === 0 ? I18n.tr("никогда") : v + I18n.tr(" с"); onMoved: v => page.g.clipClearSeconds = v }
        }
        SRow {
            icon: "shield"
            title: I18n.tr("Окно запроса прав в стиле шелла")
            desc: PolkitAuth.registered ? I18n.tr("Работает: запросы polkit показывает Cove")
                : PolkitAuth.fallback ? I18n.tr("Сейчас запросы показывает hyprpolkitagent")
                : I18n.tr("Запуск…")
            SSwitch { checked: page.g.polkit; onToggled: v => page.g.polkit = v }
        }
        SRow {
            visible: page.g.polkit
            icon: "pip"
            title: I18n.tr("Где появляется запрос")
            separator: false
            SSegment {
                options: [{ value: "center", label: I18n.tr("По центру") }, { value: "island", label: I18n.tr("Из острова") }]
                current: page.g.polkitStyle
                onPicked: v => page.g.polkitStyle = v
            }
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
            icon: "flash_off"
            title: I18n.tr("Защита от вспышки")
            desc: I18n.tr("Приглушает экран, когда он почти весь белый: светлый сайт ночью не слепит. Тёмные окна не трогает")
            SSegment {
                options: [{ value: "off", label: I18n.tr("Выкл") }, { value: "weak", label: I18n.tr("Слабо") }, { value: "strong", label: I18n.tr("Сильно") }]
                current: Settings.nightLight.antiFlash
                onPicked: v => Settings.nightLight.antiFlash = v
            }
        }
        SRow {
            icon: "󰃰"
            title: I18n.tr("По расписанию")
            SSwitch { checked: Settings.nightLight.schedule; onToggled: v => Settings.nightLight.schedule = v }
        }
        SRow {
            visible: Settings.nightLight.schedule
            icon: "wb_twilight"
            title: I18n.tr("Когда")
            desc: Settings.nightLight.bySun ? I18n.tr("Сегодня с {0} до {1} — по координатам из «Погоды»", Sun.sunsetText, Sun.sunriseText) : ""
            SSegment {
                options: [{ value: false, label: I18n.tr("По времени") }, { value: true, label: I18n.tr("От заката до восхода") }]
                current: Settings.nightLight.bySun
                onPicked: v => Settings.nightLight.bySun = v
            }
        }
        SRow {
            visible: Settings.nightLight.schedule && !Settings.nightLight.bySun
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
