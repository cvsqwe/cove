pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// «Что за песня?» (assets/songid.sh → songrec/Shazam): слушает системный звук 8 секунд.
// Пока слушает — тост в острове; результат — уведомление с обложкой и кнопкой «Открыть в Shazam»
// и строка «Исполнитель — Название» в буфере.
Singleton {
    id: root

    readonly property bool busy: proc.running
    property var last: null            // { title, artist, url, cover }
    signal listening()
    signal found(string text)
    signal notFound()

    function recognize(): void {
        if (proc.running) return;
        proc.running = true;
        listening();
    }

    Process {
        id: proc
        command: ["sh", Quickshell.shellPath("assets/songid.sh"), "8"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try { d = JSON.parse(text); } catch (e) { d = { none: true }; }
                const app = I18n.tr("Что за песня");
                if (d.missing) {
                    root.notFound();
                    Quickshell.execDetached(["notify-send", "-a", app, "-i", "audio-x-generic", I18n.tr("Не установлено"), "sudo pacman -S songrec"]);
                    return;
                }
                if (d.none) {
                    root.notFound();
                    Quickshell.execDetached(["notify-send", "-a", app, "-i", "audio-x-generic", I18n.tr("Не узнал"),
                        I18n.tr("Сделайте погромче и попробуйте ещё раз, лучше на припеве.")]);
                    return;
                }
                root.last = d;
                const line = d.artist ? `${d.artist} — ${d.title}` : d.title;
                Quickshell.execDetached(["wl-copy", line]);
                root.found(line);
                // notify-send -A ждёт ответа — в фоне
                Quickshell.execDetached(["sh", "-c", `a=$(notify-send -a "$1" -i "\${2:-audio-x-generic}" -A open="$3" "$4" "$5") ; [ "$a" = open ] && [ -n "$6" ] && xdg-open "$6"`,
                    "_", app, d.cover || "", I18n.tr("Открыть в Shazam"), d.title, (d.artist ? d.artist + " · " : "") + I18n.tr("скопировано"), d.url || ""]);
            }
        }
    }

    IpcHandler {
        target: "songid"
        function recognize(): void { root.recognize(); }
        function last(): string { return JSON.stringify(root.last); }
    }
}
