import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("О системе")

    property var info: ({})
    property bool confirmReset: false

    Process {
        running: true
        command: ["sh", "-c", [
            'echo "host=$(cat /etc/hostname)"',
            'echo "os=$(. /etc/os-release; echo $PRETTY_NAME)"',
            'echo "kernel=$(uname -r)"',
            'echo "cpu=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | sed "s/  */ /g;s/^ //")"',
            'echo "cores=$(nproc)"',
            'echo "gpu=$(lspci | grep -iE "vga|3d" | head -1 | sed "s/.*: //;s/ (rev.*//")"',
            'echo "pkgs=$(pacman -Q | wc -l)"',
            'echo "hypr=$(hyprctl version -j 2>/dev/null | grep -m1 \\"tag\\" | cut -d\\" -f4)"',
            'echo "qs=$(qs --version 2>/dev/null | head -1 | cut -d\\" \\" -f2)"',
            I18n.tr("echo \"disk=$(df -h / | tail -1 | awk \"{print \\$3\\\" из \\\"\\$2}\")\"")
        ].join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1); }
                page.info = o;
            }
        }
    }

    // шапка
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 150
        radius: Theme.radius + 4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accent }
            GradientStop { position: 1; color: Theme.accent2 }
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 22
            CoveLogo { size: 92; color: Theme.onAccent; waveColor: Theme.onAccent }
            ColumnLayout {
                spacing: 0
                StyledText { text: "cove"; font.pixelSize: 40; font.weight: Font.Light; font.letterSpacing: 6; color: Theme.onAccent }
                StyledText { text: I18n.tr("{0} · на базе {1}", page.info.host ?? "…", page.info.os ?? "Linux"); color: Theme.onAccent; opacity: 0.85 }
                StyledText { text: I18n.tr("в работе ") + System.uptime; color: Theme.onAccent; opacity: 0.7 }
            }
            Item { Layout.fillWidth: true }
        }
    }

    SCard {
        title: "Cove"
        icon: "cove"
        SRow {
            icon: "󰹑"
            title: I18n.tr("Заставка при входе")
            desc: I18n.tr("Знак Cove и приветствие — один раз за сессию")
            SButton { text: I18n.tr("Показать"); onClicked: Quickshell.execDetached(["qs", "ipc", "call", "splash", "play"]) }
            SSwitch { checked: Settings.appearance.splash; onToggled: v => Settings.appearance.splash = v }
        }
        SRow {
            icon: "waving_hand"
            title: I18n.tr("Приветствие Cove")
            desc: I18n.tr("Первый запуск: язык, имя, обои, настроение и главные хоткеи")
            SButton { text: I18n.tr("Открыть"); onClicked: Quickshell.execDetached(["qs", "ipc", "call", "welcome", "open"]) }
        }
        SRow {
            icon: "󰋩"
            title: I18n.tr("Значок в баре")
            desc: I18n.tr("Знак Cove на кнопке лаунчера")
            separator: false
            SSwitch {
                checked: Settings.bar.launcherIcon === "cove"
                onToggled: v => Settings.bar.launcherIcon = v ? "cove" : "󰣇"
            }
        }
    }

    SCard {
        title: I18n.tr("Железо и софт")
        icon: "󰍛"
        Repeater {
            model: [
                ["󰻠", I18n.tr("Процессор"), I18n.tr("{0} · {1} потоков", page.info.cpu ?? "", page.info.cores ?? "")],
                ["󰢮", I18n.tr("Видеокарта"), page.info.gpu ?? ""],
                ["󰍛", I18n.tr("Память"), I18n.tr("{0} из {1} ГБ", Sysmon.ramUsedGb.toFixed(1), Sysmon.ramTotalGb.toFixed(1))],
                ["󰋊", I18n.tr("Диск /"), page.info.disk ?? ""],
                ["󰌽", I18n.tr("Ядро"), page.info.kernel ?? ""],
                ["󰏗", I18n.tr("Пакетов"), page.info.pkgs ?? ""],
                ["", "Hyprland", page.info.hypr ?? ""],
                ["󰣆", "Quickshell", page.info.qs ?? ""]
            ]
            SRow {
                required property var modelData
                required property int index
                icon: modelData[0]
                title: modelData[1]
                separator: index < 7
                StyledText { text: modelData[2]; color: Theme.subtext1; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    SCard {
        title: I18n.tr("Обслуживание")
        icon: "󰖷"
        SRow {
            icon: "󰜉"
            title: I18n.tr("Перезапустить шелл")
            SButton { text: I18n.tr("Перезапуск"); onClicked: Quickshell.execDetached(["sh", "-c", "pkill -f '^qs$'; setsid qs >/dev/null 2>&1 &"]) }
        }
        SRow {
            icon: "fact_check"
            title: I18n.tr("Самопроверка")
            desc: I18n.tr("Открывает все окна и страницы (секунд 30 будут мелькать) и присылает итог уведомлением")
            // отдельным процессом: скрипт листает страницы настроек, и эта страница выгружается
            SButton { text: I18n.tr("Проверить"); onClicked: Quickshell.execDetached(["bash", Quickshell.shellPath("assets/selftest.sh")]) }
        }
        SRow {
            icon: "󰈮"
            title: I18n.tr("Открыть settings.json")
            desc: I18n.tr("Все настройки в одном файле — можно править руками")
            SButton { text: I18n.tr("Открыть"); onClicked: Qt.openUrlExternally("file://" + Quickshell.shellPath("settings.json")) }
        }
        SRow {
            icon: "󰦛"
            title: I18n.tr("Сбросить все настройки")
            desc: page.confirmReset ? I18n.tr("Точно? Хоткеи, оформление, правила — всё вернётся к исходному") : I18n.tr("Кроме профилей")
            separator: false
            SButton { visible: page.confirmReset; text: I18n.tr("Отмена"); onClicked: page.confirmReset = false }
            SButton {
                text: page.confirmReset ? I18n.tr("Да, сбросить") : I18n.tr("Сбросить")
                danger: true
                onClicked: {
                    if (!page.confirmReset) { page.confirmReset = true; return; }
                    const prof = Settings.copy(Settings.profiles ?? {});
                    Quickshell.execDetached(["sh", "-c", `cp "$1" "$1.bak" && printf '{"profiles": %s}' "$2" > "$1"`,
                        "_", Quickshell.shellPath("settings.json"), JSON.stringify(prof)]);
                    page.confirmReset = false;
                }
            }
        }
    }
}
