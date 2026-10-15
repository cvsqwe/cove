pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Дотфайлы в git: снимок конфигов в репозиторий, отправка на удалённый, история коммитов.
Singleton {
    id: root

    readonly property string repo: Settings.expand(Settings.dotfiles.repo)
    readonly property var paths: [".config/hypr", ".config/quickshell", ".config/kitty", ".config/gtk-3.0", ".config/gtk-4.0"]
    property bool busy: false
    property string output: ""
    property var log: []

    function sh(script: string): void {
        if (busy) return;
        busy = true;
        output = "";
        proc.command = ["sh", "-c", script, "_", repo, Settings.home, Settings.dotfiles.remote];
        proc.running = true;
    }

    function snapshot(): void {
        sh([
            'set -e; R="$1"; H="$2"; mkdir -p "$R"; cd "$R"',
            '[ -d .git ] || git init -q -b main',
            ...paths.map(p => `mkdir -p "$R/${p}" && rsync -a --delete --exclude '*.bak' --exclude '*.before-*' "$H/${p}/" "$R/${p}/"`),
            I18n.tr("printf \"# Дотфайлы\\n\\nHyprland + Quickshell. Восстановление: скопировать .config/* в ~/.config.\\n\" > README.md"),
            'git add -A',
            I18n.tr("if git diff --cached --quiet; then echo \"Изменений нет\"; else git commit -qm \"Снимок $(date +%F\\ %H:%M)\" && echo \"Сохранено: $(git log -1 --format=%s)\"; fi")
        ].join("\n"));
    }

    function push(): void {
        sh([
            'set -e; cd "$1"',
            'if [ -n "$3" ]; then git remote get-url origin >/dev/null 2>&1 && git remote set-url origin "$3" || git remote add origin "$3"; fi',
            I18n.tr("git push -u origin HEAD 2>&1 && echo \"Отправлено\"")
        ].join("\n"));
    }

    function refreshLog(): void { logProc.running = true; }

    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: root.output += text }
        stderr: StdioCollector { onStreamFinished: root.output += text }
        onExited: code => {
            root.busy = false;
            if (code !== 0 && root.output === "") root.output = I18n.tr("Ошибка (код ") + code + ")";
            root.refreshLog();
        }
    }

    Process {
        id: logProc
        command: ["sh", "-c", 'cd "$1" 2>/dev/null && git log -n 12 --format="%h\t%cr\t%s"', "_", root.repo]
        stdout: StdioCollector {
            onStreamFinished: root.log = text.split("\n").filter(Boolean).map(l => {
                const [h, t, s] = l.split("\t");
                return { hash: h, time: t, subject: s };
            })
        }
    }
}
