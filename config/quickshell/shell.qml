//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.bar
import qs.island
import qs.launcher
import qs.control
import qs.overview
import qs.wallpaper
import qs.session
import qs.lock
import qs.settings
import qs.cheatsheet
import qs.notes
import qs.desktop

ShellRoot {
    Variants {
        // панель и остров: на всех мониторах или только на основном (Настройки → Мониторы)
        model: Quickshell.screens.filter(s => Displays.hasBar(s))

        Scope {
            id: perScreen
            required property ShellScreen modelData

            Bar { screen: perScreen.modelData }
            ScreenCorners { screen: perScreen.modelData }
            Island { screen: perScreen.modelData }
        }
    }

    LauncherDim {}

    Launcher {}
    ControlCenter {}
    Overview {}
    WallpaperPicker {}
    LiveWallpaper {}
    SessionMenu {}
    PolkitPrompt {}
    Lock {}
    SettingsWindow {}
    Cheatsheet {}
    NotesDrawer {}
    DesktopWidgets {}
    Splash { id: splash }
    Welcome { id: welcome }

    // Запуск сервисов — только когда settings.json и state.json прочитаны: до этого в них
    // значения по умолчанию, и одноразовые действия (обои, палитра, конфиг Hyprland) взяли бы их.
    readonly property bool loaded: Settings.ready && Store.ready
    property bool started: false
    onLoadedChanged: start()
    Component.onCompleted: start()

    function start(): void {
        if (!loaded || started) return;
        started = true;
        HyprConfig.init(); // хоткеи и конфиг Hyprland из настроек
        AppThemes.init();
        Recolor.init();
        // поднимаем сервисы с IPC и фоновой работой
        Toggles.dnd; Screenshot.dir; Focus.active; Recorder.recording; Picker.hasColor;
        GameMode.active; Sysmon.cpu; BtAgent.passkey; Notes.dir; Dotfiles.repo;
        PolkitAuth.enabled; // свой агент polkit (или запасной hyprpolkitagent)
        Timers.active; Privacy.any; Downloads.active; Agenda.next; ClipGuard.sensitive; TerminalLook.apply(); Profiles.presets; Lens.busy; Assistant.busy; Sun.isDay; // остров: таймеры, индикаторы, календарь; пароли в буфере
        Wallpapers.restore();
        Shelf.init();
        Shelf.init();
        Notifs.count; // поднимаем сервер уведомлений сразу
        System.uptime; Keyboard.caps; // ночной свет, Caps Lock
        splash.boot();
        welcome.boot();
    }
}
