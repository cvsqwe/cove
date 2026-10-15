pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Скриншоты: область / экран / окно. Файл кладётся в ~/Pictures/Screenshots и в буфер,
// а остров показывает превью с действиями.
Singleton {
    id: root

    readonly property string dir: Settings.home + "/Pictures/Screenshots"
    property string last: ""      // путь к последнему скриншоту (для превью в острове)
    property int serial: 0        // растёт при каждом новом снимке

    function path(): string {
        return `${dir}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.png`;
    }

    function run(geomCmd: string): void {
        const f = path();
        const cmd = ["sh", "-c",
            `exec </dev/null; mkdir -p "${dir}"; ${geomCmd ? `g=$(${geomCmd}) || exit 1; grim -g "$g" "$1"` : `grim "$1"`} && wl-copy < "$1"`,
            "_", f];
        // stdin закрыт: иначе slurp ждёт из трубы Quickshell готовые прямоугольники и не появляется.
        // Прошлый снимок ещё висит:
        // гасим его, а новый запускаем после выхода. Иначе running=true молча игнорируется.
        if (shot.running) {
            shot.pending = { target: f, command: cmd };
            Quickshell.execDetached(["pkill", "-P", String(shot.processId), "-x", "slurp"]);
            shot.running = false;
            return;
        }
        shot.target = f;
        shot.command = cmd;
        shot.running = true;
    }

    // Редактор (satty): правки сохраняются поверх файла, Ctrl+C копирует в буфер.
    function edit(file: string): void {
        if (!file || editor.running) return;
        editor.command = ["sh", "-c",
            'command -v satty >/dev/null || exit 127; exec satty --filename "$1" --output-filename "$1" --copy-command wl-copy --early-exit',
            "_", file];
        editor.running = true;
    }

    function area(): void { run("slurp -d -b '#00000066' -c '" + String(Theme.accent) + "ff' -w 2"); }
    function screen(): void { run(""); }
    function window(): void {
        const t = Hyprland.activeToplevel?.lastIpcObject;
        if (!t?.at) { screen(); return; }
        run(`echo "${t.at[0]},${t.at[1]} ${t.size[0]}x${t.size[1]}"`);
    }

    Process {
        id: shot
        property string target
        property var pending: null
        onRunningChanged: {
            if (running || !pending) return;
            target = pending.target;
            command = pending.command;
            pending = null;
            running = true;
        }
        onExited: code => {
            if (code !== 0 || pending) return;
            root.last = target;
            Sounds.play("tick");
            if (Settings.island.screenshotEditor) root.edit(target);
            else root.serial++;
        }
    }

    Process {
        id: editor
        // satty не установлен — хотя бы показываем превью
        onExited: code => {
            if (code !== 127) return;
            root.serial++;
            Quickshell.execDetached(["notify-send", "-a", I18n.tr("Скриншот"), I18n.tr("Редактор не найден"), I18n.tr("Установите satty: sudo pacman -S satty")]);
        }
    }

    IpcHandler {
        target: "screenshot"
        function area(): void { root.area(); }
        function screen(): void { root.screen(); }
        function window(): void { root.window(); }
    }
}
