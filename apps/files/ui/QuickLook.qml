import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Quickshell
import qs.kit
import qs.services

// Быстрый просмотр по пробелу: картинка, видео/аудио, текст, PDF (первая страница крупно), папка.
// ← → — соседние файлы, пробел/Esc — закрыть, Enter — открыть в приложении.
Rectangle {
    id: root
    property var pane: null
    readonly property var e: pane && pane.cursor >= 0 ? pane.entries[pane.cursor] : null
    readonly property string kind: !e ? "" : e.dir ? "dir" : Fmt.isImage(e.name) ? "image" : Fmt.isVideo(e.name) ? "video"
        : Fmt.isAudio(e.name) ? "audio" : /\.pdf$/i.test(e.name) ? "pdf" : Fmt.isText(e.mime, e.name) ? "text" : "other"
    property string text_: ""
    property string pdf: ""
    signal closed()

    function show(): void { visible = true; forceActiveFocus(); load(); }
    function hide(): void { player.stop(); visible = false; closed(); }
    function step(d: int): void {
        if (!pane) return;
        const i = Math.max(0, Math.min(pane.entries.length - 1, pane.cursor + d));
        pane.selectOnly(i);
        load();
    }
    function load(): void {
        player.stop();
        text_ = "";
        pdf = "";
        if (!e) return;
        if (kind === "text")
            Ops.sh('head -c 120000 -- "$1"', [e.path], (out) => { root.text_ = out; });
        else if (kind === "pdf") {
            const out = Cove.cacheDir + "/files-preview/" + Qt.md5(e.path + e.mtime);
            Ops.sh('[ -f "$2.png" ] || { mkdir -p "$(dirname "$2")"; pdftoppm -png -singlefile -f 1 -l 1 -scale-to 1400 -- "$1" "$2"; }; echo "$2.png"', [e.path, out], o => { root.pdf = "file://" + o.trim(); });
        } else if (kind === "video" || kind === "audio") {
            player.source = Ops.uri(e.path);
            player.play();
        }
    }

    visible: false
    color: Cove.alpha(Cove.crust, 0.82)
    focus: visible
    Keys.onPressed: k => {
        if (k.key === Qt.Key_Escape || k.key === Qt.Key_Space) hide();
        else if (k.key === Qt.Key_Right || k.key === Qt.Key_Down) step(1);
        else if (k.key === Qt.Key_Left || k.key === Qt.Key_Up) step(-1);
        else if (k.key === Qt.Key_Return || k.key === Qt.Key_Enter) { if (e) Ops.open([e.path]); hide(); }
        k.accepted = true;
    }
    MouseArea { anchors.fill: parent; onClicked: root.hide(); onWheel: w => root.step(w.angleDelta.y < 0 ? 1 : -1) }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width * 0.86
        height: parent.height * 0.88
        radius: Cove.radius + 6
        color: Cove.base
        border.color: Cove.surface1
        MouseArea { anchors.fill: parent }   // клик по карточке не закрывает

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            RowLayout {
                spacing: 10
                EntryIcon { implicitWidth: 22; implicitHeight: 22; size: 22; entry: root.e; thumbs: false }
                KText { Layout.fillWidth: true; text: root.e?.name ?? ""; font.bold: true; font.pixelSize: Cove.fontSizeLarge; elide: Text.ElideMiddle }
                KText { text: root.e && !root.e.dir ? Fmt.size(root.e.size) + "  ·  " + Fmt.date(root.e.mtime) : ""; color: Cove.overlay1 }
                KButton { text: "Открыть"; icon: "open_in_new"; onClicked: { Ops.open([root.e.path]); root.hide(); } }
                KButton { icon: "close"; flat: true; onClicked: root.hide() }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Image {
                    anchors.fill: parent
                    visible: root.kind === "image" || root.kind === "pdf"
                    source: root.kind === "image" ? "file://" + root.e.path : root.kind === "pdf" ? root.pdf : ""
                    sourceSize: Qt.size(width * 1.5, height * 1.5)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
                VideoOutput {
                    id: vo
                    anchors.fill: parent
                    visible: root.kind === "video"
                }
                MediaPlayer {
                    id: player
                    videoOutput: vo
                    audioOutput: AudioOutput {}
                    loops: MediaPlayer.Infinite
                }
                // аудио: обложка + полоса
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.kind === "audio"
                    spacing: 16
                    EntryIcon { Layout.alignment: Qt.AlignHCenter; implicitWidth: 220; implicitHeight: 220; size: 220; entry: root.kind === "audio" ? root.e : null }
                    KButton {
                        Layout.alignment: Qt.AlignHCenter
                        icon: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                        primary: true
                        onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: root.kind === "video" || root.kind === "audio"
                    height: 4
                    radius: 2
                    color: Cove.surface0
                    Rectangle { width: player.duration > 0 ? parent.width * player.position / player.duration : 0; height: parent.height; radius: 2; color: Cove.accent }
                    MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: m => player.position = player.duration * m.x / width }
                }
                ScrollView {
                    anchors.fill: parent
                    visible: root.kind === "text"
                    TextArea {
                        readOnly: true
                        text: root.text_
                        color: Cove.text
                        font.family: Cove.mono
                        font.pixelSize: Cove.fontSize - 1
                        wrapMode: TextEdit.NoWrap
                        selectByMouse: true
                        background: Rectangle { color: Cove.mantle; radius: Cove.radiusSmall }
                        padding: 14
                    }
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.kind === "dir" || root.kind === "other"
                    spacing: 12
                    EntryIcon { Layout.alignment: Qt.AlignHCenter; implicitWidth: 160; implicitHeight: 160; size: 160; entry: root.kind === "dir" || root.kind === "other" ? root.e : null }
                    KText { Layout.alignment: Qt.AlignHCenter; text: root.e ? (root.e.dir ? "Папка" : Mime.describe(root.e.mime, root.e.name)) : ""; color: Cove.overlay1 }
                }
            }
        }
    }
}
