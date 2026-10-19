import QtQuick
import qs.kit
import qs.services

// Значок файла: миниатюра (картинки, видео, PDF — helpers/thumbs.py), SVG как есть, иначе значок типа из темы.
Item {
    id: root
    property var entry: null
    property real size: 64
    property bool thumbs: true
    property string thumb: ""
    readonly property bool svg: entry && !entry.dir && /\.svg$/i.test(entry.name)

    function ask(): void {
        thumb = "";
        if (thumbs && entry && !entry.dir && Thumbs.can(entry.name)) thumb = Thumbs.request(entry.path, entry.mtime);
    }
    onEntryChanged: ask()
    Component.onCompleted: ask()
    Connections {
        target: root.thumbs && root.entry && !root.entry.dir && !root.thumb ? Thumbs : null
        function onReady(p: string, t: string): void { if (p === root.entry.path) root.thumb = t; }
    }

    Image {
        id: ic
        anchors.centerIn: parent
        visible: !root.thumb && !root.svg
        width: root.size
        height: root.size
        // мелкие размеры в теме — монохромные символы: берём цветной ≥64 px и уменьшаем
        sourceSize: Qt.size(Math.max(64, root.size * 1.5), Math.max(64, root.size * 1.5))
        source: root.entry ? Mime.iconPath(root.entry.mime, root.entry.path) : ""
        asynchronous: true
        smooth: true
    }
    Image {
        id: th
        anchors.centerIn: parent
        visible: !!root.thumb || root.svg
        width: root.size
        height: root.size
        source: root.svg ? "file://" + root.entry.path : root.thumb
        sourceSize: Qt.size(root.size * 1.6, root.size * 1.6)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        // тонкая рамка вокруг самой картинки (а не всего квадрата)
        Rectangle {
            visible: th.status === Image.Ready && !root.svg
            x: (parent.width - th.paintedWidth) / 2
            y: (parent.height - th.paintedHeight) / 2
            width: th.paintedWidth
            height: th.paintedHeight
            color: "transparent"
            border.color: Cove.alpha(Cove.text, 0.12)
            radius: 3
        }
        // значок видео поверх кадра
        Rectangle {
            visible: th.status === Image.Ready && root.entry && Fmt.isVideo(root.entry.name) && root.size >= 48
            anchors.centerIn: parent
            width: Math.round(root.size * 0.3)
            height: width
            radius: width / 2
            color: Cove.alpha(Cove.crust, 0.65)
            KIcon { anchors.centerIn: parent; icon: "play_arrow"; fill: true; size: parent.width * 0.55; color: "white" }
        }
    }
}
