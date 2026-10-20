import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// Окно «Настройки» (Super+,). `qs ipc call settings open <страница>` — открыть сразу нужный раздел.
Scope {
    id: root

    property bool shown: false
    property string page: "appearance"

    readonly property var pages: [
        { id: "appearance", icon: "󰏘", label: I18n.tr("Оформление"), file: "AppearancePage", keys: I18n.tr("тема цвет палитра шрифт скругление анимации светлая тёмная акцент курсор иконки") },
        { id: "profiles", icon: "󰆓", label: I18n.tr("Профили"), file: "ProfilesPage", keys: I18n.tr("профиль пресет неон минимал уют сохранить") },
        { id: "bar", icon: "󰕮", label: I18n.tr("Панель"), file: "BarPage", keys: I18n.tr("панель модули трей воркспейсы порядок") },
        { id: "island", icon: "󱂬", label: I18n.tr("Остров"), file: "IslandPage", keys: I18n.tr("остров часы дата формат уведомления скриншот раскладка") },
        { id: "launcher", icon: "󰍉", label: I18n.tr("Лаунчер"), file: "LauncherPage", keys: I18n.tr("лаунчер меню приложения поиск сетка список spotlight") },
        { id: "firefox", icon: "󰈹", label: "Firefox", file: "FirefoxPage", keys: I18n.tr("firefox браузер вкладки стартовая страница вид userchrome") },
        { id: "windows", icon: "󰖯", label: I18n.tr("Окна"), file: "WindowsPage", keys: I18n.tr("окна отступы рамка блюр тени прозрачность раскладка анимация игровой") },
        { id: "binds", icon: "󰌌", label: I18n.tr("Хоткеи"), file: "BindsPage", keys: I18n.tr("хоткеи клавиши бинды сочетания") },
        { id: "rules", icon: "󰁨", label: I18n.tr("Правила окон"), file: "RulesPage", keys: I18n.tr("правила окна воркспейс плавающее закрепить") },
        { id: "vpn", icon: "vpn_lock", label: "VPN", file: "VpnSettingsPage", keys: I18n.tr("vpn впн прокси подписка сервер обход блокировок mihomo clash prizrak") },
        { id: "displays", icon: "monitor", label: I18n.tr("Мониторы"), file: "DisplaysPage", keys: I18n.tr("мониторы экран дисплей разрешение частота герц масштаб поворот расположение второй монитор") + " display monitor" },
        { id: "sound", icon: "graphic_eq", label: I18n.tr("Звук"), file: "SoundPage", keys: I18n.tr("звук эквалайзер бас громкость лимитер микрофон шумоподавление эхо наушники колонки") + " easyeffects equalizer eq" },
        { id: "input", icon: "󰍽", label: I18n.tr("Ввод"), file: "InputPage", keys: I18n.tr("клавиатура мышь раскладка язык повтор чувствительность") },
        { id: "notifications", icon: "󰂚", label: I18n.tr("Уведомления"), file: "NotificationsPage", keys: I18n.tr("уведомления звук не беспокоить расписание заглушить") },
        { id: "wallpaper", icon: "󰸉", label: I18n.tr("Обои"), file: "WallpaperPage", keys: I18n.tr("обои фон слайдшоу время воркспейс переход") },
        { id: "desktop", icon: "󰖲", label: I18n.tr("Рабочий стол"), file: "DesktopPage", keys: I18n.tr("виджеты рабочий стол часы заметки") },
        { id: "system", icon: "󰒓", label: I18n.tr("Система"), file: "SystemPage", keys: I18n.tr("имя город погода приложения терминал блокировка ночной свет фокус язык") + " language english" },
        { id: "terminal", icon: "terminal", label: I18n.tr("Терминал"), file: "TerminalPage", keys: I18n.tr("терминал kitty шрифт курсор вкладки прозрачность fish fastfetch") },
        { id: "time", icon: "schedule", label: I18n.tr("Время"), file: "TimePage", keys: I18n.tr("будильник таймер календарь события напоминание ics google") },
        { id: "screentime", icon: "hourglass", label: I18n.tr("Экранное время"), file: "ScreenTimePage", keys: I18n.tr("экранное время приложения часы статистика неделя благополучие") + " screen time wellbeing" },
        { id: "autostart", icon: "󰐊", label: I18n.tr("Автозапуск"), file: "AutostartPage", keys: I18n.tr("автозапуск старт приложения") },
        { id: "dotfiles", icon: "󰊢", label: I18n.tr("Дотфайлы"), file: "DotfilesPage", keys: I18n.tr("git дотфайлы бэкап синхронизация") },
        { id: "about", icon: "cove", label: I18n.tr("О системе"), file: "AboutPage", keys: I18n.tr("система версия железо сброс cove заставка логотип бренд") }
    ]

    function open(p: string): void {
        if (p && pages.some(x => x.id === p)) page = p;
        shown = true;
        Panels.closeAll();
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.shown ? (root.shown = false) : root.open(""); }
        function open(page: string): void { root.open(page); }
        // qs ipc call settings get appearance tileOn — значение в памяти шелла (для проверки)
        function get(section: string, key: string): string { return JSON.stringify(Settings[section]?.[key]); }
    }

    // открыть из Panels (шестерёнка в центре управления)
    Connections {
        target: Panels
        function onSettingsRequested(page: string): void { root.open(page); }
    }

    FloatingWindow {
        id: win
        visible: root.shown
        title: I18n.tr("Настройки Quickshell")
        implicitWidth: 1180
        implicitHeight: 760
        minimumSize: Qt.size(900, 560)
        color: Theme.base
        onVisibleChanged: if (!visible) root.shown = false

        Shortcut { sequence: "Escape"; onActivated: root.shown = false }
        Shortcut { sequence: "Ctrl+F"; onActivated: search.forceActiveFocus() }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---- боковая панель ----
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 250
                color: Theme.mantle

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.leftMargin: 6
                        Layout.topMargin: 6
                        spacing: 10
                        Rectangle {
                            implicitWidth: 36; implicitHeight: 36; radius: 18
                            color: Theme.accent
                            MIcon { anchors.centerIn: parent; icon: "󰒓"; color: Theme.onAccent; size: 18 }
                            RotationAnimation on rotation { running: win.visible; from: 0; to: 360; duration: 12000; loops: Animation.Infinite }
                        }
                        ColumnLayout {
                            spacing: 0
                            StyledText { text: I18n.tr("Настройки"); font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                            StyledText { text: Settings.displayName; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
                        }
                    }

                    SField {
                        id: search
                        Layout.fillWidth: true
                        placeholderText: I18n.tr("Поиск настроек")
                    }

                    ListView {
                        id: nav
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.pages.filter(p => {
                            const q = search.text.trim().toLowerCase();
                            return q === "" || p.label.toLowerCase().includes(q) || p.keys.includes(q);
                        })

                        delegate: Rectangle {
                            id: item
                            required property var modelData
                            readonly property bool current: root.page === modelData.id
                            width: ListView.view.width
                            height: 40
                            radius: Theme.radiusSmall + 2
                            color: current ? Theme.accent : hov.containsMouse ? Theme.surface0 : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                spacing: 12
                                MIcon {
                                    Layout.preferredWidth: 20
                                    icon: item.modelData.icon
                                    color: item.current ? Theme.onAccent : Theme.accent
                                    size: 16
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: item.modelData.label
                                    color: item.current ? Theme.onAccent : Theme.text
                                    font.bold: item.current
                                }
                            }
                            MouseArea {
                                id: hov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.page = item.modelData.id
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: HyprConfig.lastError ? I18n.tr("Ошибка конфига Hyprland — изменение отменено") : I18n.tr("Изменения применяются сразу")
                        color: HyprConfig.lastError ? Theme.red : Theme.overlay0
                        font.pixelSize: Theme.fontSizeSmall - 1
                        wrapMode: Text.Wrap
                    }
                }
            }

            // ---- страница ----
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: loader
                    anchors.fill: parent
                    active: win.visible
                    readonly property var p: root.pages.find(x => x.id === root.page)
                    source: p ? Qt.resolvedUrl(`pages/${p.file}.qml`) : ""
                    opacity: status === Loader.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: loader.status === Loader.Error
                    text: I18n.tr("Страница не загрузилась — подробности в логе: qs log")
                    color: Theme.red
                }
            }
        }
    }
}
