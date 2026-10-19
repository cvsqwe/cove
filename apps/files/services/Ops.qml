pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.kit

// Операции с файлами: долгие — через helpers/ops.py с прогрессом (список jobs),
// быстрые — сразу. Буфер обмена общий с другими приложениями (text/uri-list).
Singleton {
    id: root

    readonly property string opsPy: Quickshell.shellPath("helpers/ops.py")
    readonly property string fmPy: Quickshell.shellPath("helpers/fm.py")
    property var jobs: []                 // [{ id, title, icon, done, total, file, proc }]
    property var clip: ({ paths: [], cut: false })
    property int nextId: 1

    // UI подписывается: спросить, что делать с занятыми именами → answer("replace"|"skip"|"rename"|"")
    signal conflict(var names, var answer)
    signal failed(string title, var errors)
    signal created(var paths)
    signal noTrash(var paths)             // на этом диске корзины нет — спросить про удаление насовсем             // выделить то, что появилось (вставка, новая папка)

    function fm(args: var, cb: var): void {
        const p = procC.createObject(root, { command: ["python3", fmPy, ...args] });
        p.done = (out, code) => { if (cb) { let v = null; try { v = JSON.parse(out); } catch (e) {} cb(v, code); } };
    }
    function sh(script: string, args: var, cb: var): void {
        const p = procC.createObject(root, { command: ["sh", "-c", script, "_", ...args] });
        p.done = (out, code) => { if (cb) cb(out, code); };
    }

    // ---------- долгие операции ----------

    function job(title: string, icon: string, args: var): void {
        const j = { id: nextId++, title, icon, done: 0, total: 0, file: "", started: Date.now() };
        const p = jobC.createObject(root, { command: ["python3", opsPy, ...args] });
        j.proc = p;
        p.job = j;
        jobs = jobs.concat([j]);
    }
    function update(j: var, ev: var): void {
        if (ev.t === "progress") {
            j.done = ev.done; j.total = ev.total; j.file = ev.file ?? "";
            jobs = jobs.slice();  // обновить привязки
        } else if (ev.t === "done") {
            jobs = jobs.filter(x => x.id !== j.id);
            if (ev.errors?.length) failed(j.title, ev.errors);
            if (ev.unsupported?.length) noTrash(ev.unsupported);
            if (ev.created?.length) created(ev.created);
            if (Date.now() - j.started > 4000 && !ev.cancelled)
                Quickshell.execDetached(["notify-send", "-a", "Cove Files", "-i", "folder", j.title, "Готово"]);
        }
    }
    function cancel(id: int): void {
        const j = jobs.find(x => x.id === id);
        if (j?.proc) j.proc.signal(15);
    }

    function transfer(paths: var, dest: string, move: bool): void {
        if (!paths.length) return;
        const title = (move ? "Перемещение " : "Копирование ") + count(paths.length);
        const p = procC.createObject(root, { command: ["python3", opsPy, "check", dest, ...paths] });
        p.done = out => {
            let names = [];
            try { names = JSON.parse(out); } catch (e) {}
            const go = policy => { if (policy) job(title, move ? "drive_file_move" : "content_copy", [move ? "move" : "copy", policy, dest, ...paths]); };
            if (names.length) conflict(names, go);
            else go("rename");
        };
    }
    function trash(paths: var): void { if (paths.length) job("В корзину: " + count(paths.length), "delete", ["trash", ...paths]); }
    function remove(paths: var): void { if (paths.length) job("Удаление " + count(paths.length), "delete_forever", ["delete", ...paths]); }
    function extract(paths: var, dest: string): void { job("Распаковка", "unarchive", ["extract", dest, ...paths]); }
    function compress(paths: var, archive: string): void { job("Сжатие", "archive", ["compress", archive, ...paths]); }

    function count(n: int): string { return Fmt.items(n); }

    // ---------- быстрые операции ----------

    function mkdir(dir: string, name: string, cb: var): void {
        sh('[ -e "$1/$2" ] && { echo exists; exit 1; }; mkdir -- "$1/$2"', [dir, name], (o, c) => {
            if (c === 0) created([dir + "/" + name]);
            if (cb) cb(c === 0 ? "" : (o.trim() === "exists" ? "Такое имя уже есть" : "Не удалось создать"));
        });
    }
    function touch(dir: string, name: string, cb: var): void {
        sh('[ -e "$1/$2" ] && { echo exists; exit 1; }; : > "$1/$2"', [dir, name], (o, c) => {
            if (c === 0) created([dir + "/" + name]);
            if (cb) cb(c === 0 ? "" : (o.trim() === "exists" ? "Такое имя уже есть" : "Не удалось создать"));
        });
    }
    function rename(path: string, name: string, cb: var): void {
        const dir = path.slice(0, path.lastIndexOf("/"));
        sh('[ -e "$2" ] && [ "$(realpath -- "$1")" != "$(realpath -- "$2")" ] && { echo exists; exit 1; }; mv -- "$1" "$2"', [path, dir + "/" + name], (o, c) => {
            if (c === 0) created([dir + "/" + name]);
            if (cb) cb(c === 0 ? "" : (o.trim() === "exists" ? "Такое имя уже есть" : "Не удалось переименовать"));
        });
    }
    function restore(names: var): void { fm(["restore", ...names], v => { if (v?.errors?.length) failed("Восстановление", v.errors); }); }
    function emptyTrash(): void { fm(["empty"], null); }

    // ---------- открыть ----------

    function open(paths: var): void { for (const p of paths) Quickshell.execDetached(["gio", "open", p]); }
    function openWith(desktopId: string, paths: var): void { fm(["launch", desktopId, ...paths], null); }
    function terminal(dir: string): void {
        Quickshell.execDetached(["sh", "-c", 'cd "$1" && exec "${TERMINAL:-kitty}"', "_", dir]);
    }
    function setWallpaper(path: string): void {
        Quickshell.execDetached(["sh", "-c", 'qs ipc call wallpaper set "$1" 2>/dev/null || notify-send -a "Cove Files" "Обои меняет шелл Cove" "Он сейчас не запущен."', "_", path]);
    }

    // ---------- буфер обмена ----------

    function uri(p: string): string { return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F"); }

    function copy(paths: var, cut: bool): void {
        if (!paths.length) return;
        clip = { paths: paths.slice(), cut };
        // wl-copy держит буфер сам, пока его не заменят
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy -t text/uri-list', "_", paths.map(uri).join("\r\n")]);
    }
    function copyText(t: string): void {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "_", t]);
    }

    // что в буфере: файлы → копировать/переместить; картинка или текст → сохранить файлом
    function paste(dest: string): void {
        sh('t=$(wl-paste -l 2>/dev/null) || exit 1\n' +
           'if echo "$t" | grep -qx "text/uri-list"; then echo FILES; wl-paste -n -t text/uri-list; exit 0; fi\n' +
           'img=$(echo "$t" | grep -m1 -x "image/\\(png\\|jpeg\\|webp\\)")\n' +
           'if [ -n "$img" ]; then ext=${img#image/}; [ "$ext" = jpeg ] && ext=jpg; f="$1/Изображение $(date +%Y-%m-%d\\ %H.%M.%S).$ext"; wl-paste -t "$img" > "$f" && echo "SAVED $f"; exit 0; fi\n' +
           'if echo "$t" | grep -q "^text/plain"; then f="$1/Текст $(date +%Y-%m-%d\\ %H.%M.%S).txt"; wl-paste -n > "$f" && echo "SAVED $f"; fi',
           [dest], out => {
            const lines = out.split(/\r?\n/).filter(Boolean);
            if (lines[0] === "FILES") {
                const paths = lines.slice(1).filter(l => l.startsWith("file://")).map(l => decodeURIComponent(l.slice(7)));
                const cut = clip.cut && paths.length === clip.paths.length && paths.every(p => clip.paths.includes(p));
                transfer(paths, dest, cut);
                if (cut) clip = { paths: [], cut: false };
            } else if (lines[0]?.startsWith("SAVED ")) {
                created([lines[0].slice(6)]);
            }
        });
    }

    Component { id: procC; Proc {} }
    Component {
        id: jobC
        Process {
            id: jp
            property var job: null
            running: true
            stdout: SplitParser {
                onRead: ln => { try { root.update(jp.job, JSON.parse(ln)); } catch (e) {} }
            }
            onExited: Qt.callLater(() => {
                if (root.jobs.some(x => x.id === jp.job.id)) root.jobs = root.jobs.filter(x => x.id !== jp.job.id);
                jp.destroy();
            })
        }
    }
}
