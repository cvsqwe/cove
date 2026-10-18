import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// График сети: приём и отдача за последние 2 минуты, масштаб — по пику в окне.
ColumnLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)

    spacing: 8
    implicitWidth: 300

    readonly property real peak: Math.max(64 * 1024, ...Sysmon.rxHistory, ...Sysmon.txHistory)
    function norm(arr): var { return arr.map(v => v / root.peak); }

    RowLayout {
        spacing: 14
        MIcon { icon: "lan"; color: Theme.accent; size: Theme.iconSize }
        StyledText { text: I18n.tr("Сеть"); font.bold: true; Layout.fillWidth: true }
        Row {
            spacing: 4
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "arrow_downward"; size: Theme.fontSize; color: Theme.teal }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: Downloads.human(Sysmon.netRx) + I18n.tr("/с"); color: Theme.teal; font.pixelSize: Theme.fontSizeSmall }
        }
        Row {
            spacing: 4
            MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "arrow_upward"; size: Theme.fontSize; color: Theme.accent2 }
            StyledText { anchors.verticalCenter: parent.verticalCenter; text: Downloads.human(Sysmon.netTx) + I18n.tr("/с"); color: Theme.accent2; font.pixelSize: Theme.fontSizeSmall }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: root.opts.height ?? 90
        Sparkline { anchors.fill: parent; values: root.norm(Sysmon.rxHistory); color: Theme.teal }
        Sparkline { anchors.fill: parent; values: root.norm(Sysmon.txHistory); color: Theme.accent2 }
    }
    StyledText {
        text: I18n.tr("пик {0}/с", Downloads.human(root.peak))
        color: Theme.overlay0
        font.pixelSize: Theme.fontSizeSmall - 1
    }
}
