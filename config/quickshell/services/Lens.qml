pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Умные инструменты экрана: текст с области (tesseract, русский + английский), его перевод и QR-коды (zbarimg).
// Результат — в буфер обмена и в уведомление; ссылку из QR можно открыть кнопкой уведомления.
Singleton {
    id: root

    property bool busy: proc.running

    function slurp(): string {
        return "slurp -d -b '#00000066' -c '" + String(Theme.accent) + "ff' -w 2";
    }

    // file: готовая картинка (например, последний скриншот) или пусто — выбрать область
    function text(file: string): void { run("text", file ?? ""); }
    // перевод с экрана: область → текст → перевод карточкой поверх области (lens/TranslateOverlay.qml)
    function translate(): void { run("translate", ""); }
    function qr(file: string): void { run("qr", file ?? ""); }

    function run(mode: string, file: string): void {
        if (proc.running) return;
        proc.mode = mode;
        proc.command = ["sh", "-c", root.script, "_", mode, file, root.slurp(),
            I18n.tr("Текст с экрана"), I18n.tr("QR-код"), I18n.tr("Скопировано"), I18n.tr("Ничего не найдено"),
            I18n.tr("Не установлено"), I18n.tr("Открыть")];
        proc.running = true;
    }

    // stdin закрыт: иначе slurp ждёт прямоугольники из трубы Quickshell (см. Screenshot.qml)
    readonly property string script: 'exec </dev/null
        mode=$1 file=$2 sel=$3 tText=$4 tQr=$5 tCopied=$6 tNone=$7 tMissing=$8 tOpen=$9
        title=$tText; [ "$mode" = qr ] && title=$tQr
        if [ "$mode" != qr ]; then
            command -v tesseract >/dev/null || { notify-send -a "$title" -i scanner "$tMissing" "sudo pacman -S tesseract tesseract-data-rus tesseract-data-eng"; exit 0; }
            langs=$(tesseract --list-langs 2>/dev/null | grep -xE "rus|eng" | paste -sd+)
        else
            command -v zbarimg >/dev/null || { notify-send -a "$title" -i scanner "$tMissing" "sudo pacman -S zbar"; exit 0; }
        fi
        tmp=$(mktemp --suffix=.png); trap "rm -f $tmp" EXIT
        if [ -n "$file" ]; then cp -- "$file" "$tmp" || exit 1
        else g=$(eval "$sel") || exit 0; grim -g "$g" "$tmp" || exit 1; fi
        if [ "$mode" != qr ]; then
            # мелкий текст с экрана распознаётся лучше в сером и увеличенным втрое
            command -v magick >/dev/null && magick "$tmp" -colorspace Gray -resize 300% "$tmp"
            res=$(tesseract "$tmp" - -l "${langs:-eng}" --psm 3 2>/dev/null | sed -e "s/[[:space:]]*$//" | cat -s | sed -e "/./,\\$!d")
        else
            res=$(zbarimg -q --raw "$tmp" 2>/dev/null)
        fi
        [ -n "$res" ] || { notify-send -a "$title" -i scanner "$tNone"; exit 0; }
        # перевод: область и текст — шеллу, дальше он сам
        if [ "$mode" = translate ]; then printf "%s\n%s" "$g" "$res"; exit 0; fi
        printf %s "$res" | wl-copy
        body=$(printf %s "$res" | head -c 300)
        case "$res" in
            http://*|https://*)   # notify-send -A ждёт ответа — в фоне, чтобы не держать следующий снимок
                { [ "$(notify-send -a "$title" -i scanner -A open="$tOpen" "$tCopied" "$body")" = open ] && xdg-open "$res"; } >/dev/null 2>&1 & ;;
            *) notify-send -a "$title" -i scanner "$tCopied" "$body" ;;
        esac'

    Process {
        id: proc
        property string mode: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.mode !== "translate" || text.trim() === "") return;
                const nl = text.indexOf("\n");
                root.startTranslate(text.slice(0, nl), text.slice(nl + 1));
            }
        }
    }

    // ---- перевод ----
    // geom: «X,Y WxH» из slurp; overlay показывает карточку, пока ждём перевод — «Перевожу…»
    property var tr: null   // { x, y, w, h, original, text, busy, error, engine }
    function startTranslate(geom: string, original: string): void {
        const m = geom.match(/(-?\d+),(-?\d+) (\d+)x(\d+)/);
        tr = { x: m ? +m[1] : 200, y: m ? +m[2] : 200, w: m ? +m[3] : 400, h: m ? +m[4] : 100,
               original: original, text: "", busy: true, error: "", engine: "" };
        trProc.command = ["sh", "-c", 'printf %s "$1" | python3 "$2" "$3"', "_", original, Quickshell.shellPath("assets/translate.py"), I18n.lang];
        trProc.running = true;
    }
    function closeTranslate(): void { tr = null; }
    Process {
        id: trProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.tr) return;
                let d = {};
                try { d = JSON.parse(text); } catch (e) { d = { error: "offline" }; }
                root.tr = Object.assign({}, root.tr, { busy: false, text: d.text ?? "", engine: d.engine ?? "",
                    error: d.error ? I18n.tr("Не удалось перевести: нет связи с сервисами перевода") : "" });
            }
        }
    }

    IpcHandler {
        target: "lens"
        function text(): void { root.text(""); }
        function qr(): void { root.qr(""); }
        function translate(): void { root.translate(); }
        function textFile(path: string): void { root.text(path); }
        function qrFile(path: string): void { root.qr(path); }
    }
}
