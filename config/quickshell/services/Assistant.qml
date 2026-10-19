pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Ассистент в лаунчере (префикс *): разговор живёт до «Новый чат», ответы идут потоком.
// Провайдер и модель — Settings.assistant, сам запрос — assets/assistant.py.
// Ключ API хранится в ~/.local/state/cove/assistant.key (права 600): не в settings.json и не в экспорте профиля.
Singleton {
    id: root

    readonly property string keyFile: Settings.home + "/.local/state/cove/assistant.key"
    readonly property string venv: Settings.home + "/.local/share/cove/assistant-venv"

    property var messages: []          // [{ role: "user" | "assistant", content }]
    property string error: ""
    readonly property bool busy: proc.running
    property bool hasKey: false
    property bool hasSdk: false
    property bool installing: installer.running
    property string installLog: ""

    readonly property var providers: [
        { value: "claude", label: "Claude Code", hint: I18n.tr("Через установленный Claude Code (claude -p) и его вход — ключ не нужен") },
        { value: "anthropic", label: "Anthropic API", hint: I18n.tr("Ключ API с platform.claude.com; по умолчанию модель claude-opus-5-5") },
        { value: "openai", label: I18n.tr("OpenAI-совместимый"), hint: I18n.tr("Любой сервис с /chat/completions: адрес, ключ и модель") },
        { value: "ollama", label: "Ollama", hint: I18n.tr("Локальная модель, без интернета: нужен запущенный ollama serve") },
        { value: "off", label: I18n.tr("Выключен"), hint: I18n.tr("Префикс * ничего не спрашивает") }
    ]
    readonly property bool needsKey: ["anthropic", "openai"].includes(Settings.assistant.provider)
    readonly property bool needsSdk: Settings.assistant.provider === "anthropic"

    function ask(q: string): void {
        q = (q ?? "").trim();
        if (q === "" || proc.running) return;
        error = "";
        messages = [...messages, { role: "user", content: q }, { role: "assistant", content: "" }];
        const a = Settings.assistant;
        // вопрос уходит с историей, без пустого черновика ответа
        const history = messages.slice(0, -1).filter(m => m.content !== "");
        const python = needsSdk && hasSdk ? venv + "/bin/python" : "python3";
        proc.command = [python, Quickshell.shellPath("assets/assistant.py"), a.provider, a.model, a.baseUrl, JSON.stringify(history)];
        proc.running = true;
    }

    function stop(): void { if (proc.running) proc.signal(15); }

    function reset(): void {
        stop();
        messages = [];
        error = "";
    }

    readonly property string lastAnswer: {
        for (let i = messages.length - 1; i >= 0; i--)
            if (messages[i].role === "assistant" && messages[i].content) return messages[i].content;
        return "";
    }

    function append(text: string): void {
        const m = messages.slice();
        const last = m[m.length - 1];
        m[m.length - 1] = { role: last.role, content: last.content + text };
        messages = m;
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => {
                let d;
                try { d = JSON.parse(line); } catch (e) { return; }
                if (d.t === "text") root.append(d.v);
                else if (d.t === "error") root.error = d.v;
            }
        }
        onExited: code => {
            // пустой черновик (ошибка до первого слова) убираем, вопрос оставляем — его можно переспросить
            const m = root.messages;
            if (m.length && m[m.length - 1].role === "assistant" && m[m.length - 1].content === "")
                root.messages = m.slice(0, -1);
            if (code !== 0 && root.error === "") root.error = I18n.tr("Ответ прерван");
        }
    }

    // ---- ключ API ----
    function saveKey(k: string): void {
        keyWriter.payload = (k ?? "").trim();
        keyWriter.running = true;
    }
    Process {
        id: keyWriter
        property string payload: ""
        // ключ идёт через stdin, а не аргументом — не светится в списке процессов
        command: ["sh", "-c", 'umask 077; mkdir -p "$(dirname "$1")"; if [ -n "$2" ]; then cat > "$1"; else rm -f "$1"; fi', "_", root.keyFile, payload === "" ? "" : "1"]
        stdinEnabled: true
        onStarted: { if (payload !== "") write(payload); stdinEnabled = false; }
        onExited: { stdinEnabled = true; payload = ""; check.running = true; }
    }

    // ---- библиотека anthropic в своём venv (системный pip трогать нельзя) ----
    function installSdk(): void {
        installLog = "";
        installer.running = true;
    }
    Process {
        id: installer
        command: ["sh", "-c", 'exec </dev/null; python3 -m venv "$1" && "$1/bin/pip" install -q --upgrade anthropic 2>&1 | tail -3', "_", root.venv]
        stdout: StdioCollector { onStreamFinished: root.installLog = text.trim() }
        onExited: check.running = true
    }

    Process {
        id: check
        command: ["sh", "-c", 'test -s "$1" && echo key; "$2/bin/python" -c "import anthropic" 2>/dev/null && echo sdk', "_", root.keyFile, root.venv]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasKey = text.includes("key");
                root.hasSdk = text.includes("sdk");
            }
        }
    }
    Component.onCompleted: check.running = true

    // qs ipc call assistant ask "вопрос" — ответ появится в лаунчере (*), текст — qs ipc call assistant last
    IpcHandler {
        target: "assistant"
        function ask(q: string): void { root.ask(q); }
        function reset(): void { root.reset(); }
        function last(): string { return root.lastAnswer; }
        function status(): string { return root.busy ? "busy" : root.error !== "" ? "error: " + root.error : "idle"; }
    }
}
