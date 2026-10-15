import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: Media.playing
    signal setOpt(string key, var value)
    implicitWidth: vis.implicitWidth
    implicitHeight: root.opts.height ?? 120
    Visualizer {
        id: vis
        anchors.verticalCenter: root.opts.mirrored !== false ? parent.verticalCenter : undefined
        anchors.bottom: root.opts.mirrored !== false ? undefined : parent.bottom
        step: 1
        barWidth: 8
        spacing: 5
        maxHeight: root.opts.height ?? 120
        minHeight: 3
        mirrored: root.opts.mirrored !== false
        color: Theme.accent
    }
}
