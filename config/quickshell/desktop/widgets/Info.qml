import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

RowLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    spacing: 22
    property string os: "Linux"
    property string kernel: ""
    property string host: ""

    FileView {
        path: "/etc/os-release"
        onLoaded: { const m = text().match(/^PRETTY_NAME="?([^"\n]*)"?/m); if (m) root.os = m[1]; }
    }
    FileView { path: "/etc/hostname"; onLoaded: root.host = text().trim() }
    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector { onStreamFinished: root.kernel = text.trim() }
    }

    MIcon { Layout.alignment: Qt.AlignVCenter; icon: "cove"; size: 72; color: Theme.accent }
    ColumnLayout {
        spacing: 3
        StyledText {
            text: Quickshell.env("USER") + "<font color='" + Theme.overlay1 + "'>@</font>" + root.host
            textFormat: Text.StyledText
            font.bold: true
            color: Theme.accent
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.text, 0.1) }
        // список строк постоянный, значения — внутри: иначе каждый замер памяти пересоздавал строки
        Repeater {
            model: ["os", "kernel", "wm", "uptime", "ram"]
            RowLayout {
                id: row
                required property string modelData
                spacing: 10
                MIcon {
                    icon: ({ os: "󰣇", kernel: "", wm: "", uptime: "󰅐", ram: "󰍛" })[row.modelData]
                    color: Theme.accent
                    Layout.preferredWidth: 18
                }
                StyledText {
                    text: row.modelData === "os" ? root.os : row.modelData === "kernel" ? root.kernel
                        : row.modelData === "wm" ? "Hyprland + Quickshell" : row.modelData === "uptime" ? System.uptime
                        : Sysmon.ramUsedGb.toFixed(1) + " / " + Sysmon.ramTotalGb.toFixed(1) + " ГБ"
                    color: Theme.subtext1
                }
            }
        }
        Row {
            Layout.topMargin: 4
            spacing: 6
            Repeater {
                model: [Theme.red, Theme.peach, Theme.yellow, Theme.green, Theme.teal, Theme.accent2, Theme.accent]
                Rectangle { required property color modelData; width: 14; height: 14; radius: 7; color: modelData }
            }
        }
    }
}
