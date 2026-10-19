pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Тип файла по имени (база shared-mime-info: globs2 + generic-icons) и значок для него.
Singleton {
    id: root
    property var ext: ({})        // «py» → «text/x-python»
    property var names: ({})      // «makefile» → тип по полному имени
    property var generic: ({})    // тип → общий значок («text-x-generic»)
    property var desc: ({
        "inode/directory": "Папка", "text/plain": "Текст", "application/pdf": "PDF", "application/zip": "Архив ZIP",
        "image/png": "Изображение PNG", "image/jpeg": "Изображение JPEG", "video/mp4": "Видео MP4"
    })

    function of(name: string, isDir: bool): string {
        if (isDir) return "inode/directory";
        const n = name.toLowerCase();
        if (names[n]) return names[n];
        // самое длинное подходящее расширение: «tar.gz» раньше «gz»
        let i = n.indexOf(".", n.startsWith(".") ? 1 : 0);
        while (i >= 0) {
            const e = n.slice(i + 1);
            if (ext[e]) return ext[e];
            i = n.indexOf(".", i + 1);
        }
        return "application/octet-stream";
    }

    // имя значка из темы; специальные папки — свои значки
    function icon(mime: string, path: string): string {
        if (mime === "inode/directory") {
            const h = Quickshell.env("HOME");
            const special = { "": "user-home", "/Desktop": "user-desktop", "/Documents": "folder-documents", "/Downloads": "folder-download",
                "/Music": "folder-music", "/Pictures": "folder-pictures", "/Videos": "folder-videos", "/Public": "folder-publicshare",
                "/Templates": "folder-templates", "/Projects": "folder-development", "/Wallpapers": "folder-pictures" };
            if (path.startsWith(h)) {
                const s = special[path.slice(h.length)];
                if (s) return s;
            }
            return "folder";
        }
        return mime.replace("/", "-");
    }
    function iconPath(mime: string, path: string): string {
        const name = icon(mime, path);
        return Quickshell.iconPath(name, true) || Quickshell.iconPath(generic[mime] ?? "", true)
            || Quickshell.iconPath(mime.split("/")[0] + "-x-generic", true) || Quickshell.iconPath(mime === "inode/directory" ? "folder" : "text-x-generic", true)
            || Quickshell.iconPath("unknown");
    }

    // понятное название типа: из словаря, иначе «Файл PY»
    function describe(mime: string, name: string): string {
        if (desc[mime]) return desc[mime];
        const top = mime.split("/")[0];
        const e = name.includes(".") ? name.split(".").pop().toUpperCase() : "";
        const kind = { image: "Изображение", video: "Видео", audio: "Аудио", text: "Текст", font: "Шрифт" }[top] ?? "Файл";
        return e ? kind + " " + e : kind;
    }

    FileView {
        path: "/usr/share/mime/globs2"
        printErrors: false
        onLoaded: {
            const e = {}, n = {};
            for (const ln of text().split("\n")) {
                if (!ln || ln[0] === "#") continue;
                const parts = ln.split(":");
                if (parts.length < 3) continue;
                const mime = parts[1], glob = parts[2].toLowerCase();
                if (/^\*\.[^*?\[]+$/.test(glob)) { const k = glob.slice(2); if (!e[k]) e[k] = mime; }
                else if (!/[*?\[]/.test(glob)) { if (!n[glob]) n[glob] = mime; }
            }
            root.ext = e;
            root.names = n;
        }
    }
    FileView {
        path: "/usr/share/mime/generic-icons"
        printErrors: false
        onLoaded: {
            const g = {};
            for (const ln of text().split("\n")) {
                const i = ln.indexOf(":");
                if (i > 0) g[ln.slice(0, i)] = ln.slice(i + 1);
            }
            root.generic = g;
        }
    }
}
