import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Плеер на рабочем столе. Вид (opts.layout):
//   card   — обложка слева, справа трек и кнопки
//   tall   — большая обложка сверху
//   mini   — узкая полоска
//   vinyl  — крутящаяся пластинка с тонармом
//   lyrics — крупный текст песни, трек мелко сверху
// Текст песни (opts.lyrics): off | line | lines; спектр (opts.spectrum): off | strip | back;
// opts.progress, opts.controls, opts.extra (перемешивание/повтор).
Item {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: Media.active
    signal setOpt(string key, var value)

    readonly property var p: Media.player
    readonly property string layout: opts.layout ?? "card"
    readonly property string lyricsMode: layout === "lyrics" ? "lines" : (opts.lyrics ?? "off")
    readonly property string spectrum: opts.spectrum ?? "strip"
    readonly property bool progress: opts.progress !== false
    readonly property bool controls: opts.controls !== false
    readonly property bool extra: opts.extra === true

    // ширина задаётся видом, а не раскладкой: implicitWidth у ColumnLayout пересчитывается по детям
    readonly property int layoutWidth: ({ card: 400, tall: 280, mini: 360, vinyl: 470, lyrics: 460 })[layout] ?? 400
    implicitWidth: layoutWidth
    implicitHeight: lay.item?.implicitHeight ?? 120

    // старый ключ visualizer: false → spectrum: off
    onOptsChanged: if (opts.visualizer === false) { setOpt("visualizer", undefined); setOpt("spectrum", "off"); }

    // cava и LRCLIB работают только пока они кому-то нужны
    property bool holdsSpectrum: false
    property bool holdsLyrics: false
    function hold(): void {
        const s = spectrum !== "off", l = lyricsMode !== "off";
        if (s !== holdsSpectrum) { Media.spectrumUsers += s ? 1 : -1; holdsSpectrum = s; }
        if (l !== holdsLyrics) { Lyrics.users += l ? 1 : -1; holdsLyrics = l; }
    }
    onSpectrumChanged: hold()
    onLyricsModeChanged: hold()
    Component.onCompleted: hold()
    Component.onDestruction: {
        if (holdsSpectrum) Media.spectrumUsers -= 1;
        if (holdsLyrics) Lyrics.users -= 1;
    }

    // спектр фоном — во всю ширину вдоль нижнего края, бледно
    Visualizer {
        visible: root.spectrum === "back"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        bands: Math.max(4, Math.floor((root.width + spacing) / (barWidth + spacing)))
        barWidth: 6
        spacing: 4
        maxHeight: Math.min(root.height, 90)
        minHeight: 0
        fade: true
        opacity: Media.playing ? 0.3 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    }

    Loader {
        id: lay
        width: root.layoutWidth
        sourceComponent: ({ card: cardL, tall: tallL, mini: miniL, vinyl: vinylL, lyrics: lyricsL })[root.layout] ?? cardL
    }

    // ================= виды =================

    Component {
        id: cardL
        ColumnLayout {
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Cover { size: 112; Layout.alignment: Qt.AlignTop }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    TrackInfo { Layout.fillWidth: true }
                    Strip { visible: root.spectrum === "strip"; Layout.topMargin: 6; Layout.fillWidth: true }
                    Item { Layout.fillHeight: true }
                    Progress { visible: root.progress; Layout.fillWidth: true }
                    Controls { visible: root.controls; withExtra: root.extra }
                }
            }
            LyricsView { visible: root.lyricsMode !== "off"; Layout.fillWidth: true; rows: root.lyricsMode === "lines" ? 3 : 1 }
        }
    }

    Component {
        id: tallL
        ColumnLayout {
            spacing: 10
            Item {
                Layout.fillWidth: true
                implicitHeight: 280
                Cover { size: 280; radius: Theme.radius + 4 }
                // спектр прямо по нижнему краю обложки
                Rectangle {
                    visible: root.spectrum === "strip"
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 64
                    radius: Theme.radius + 4
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Theme.alpha(Theme.crust, 0.7) }
                    }
                    Strip {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                        barHeight: 28
                        tint: Theme.text
                    }
                }
            }
            TrackInfo { Layout.fillWidth: true; Layout.topMargin: 4; centered: true }
            LyricsView { visible: root.lyricsMode !== "off"; Layout.fillWidth: true; rows: root.lyricsMode === "lines" ? 3 : 1; centered: true }
            Progress { visible: root.progress; Layout.fillWidth: true }
            Controls { visible: root.controls; Layout.alignment: Qt.AlignHCenter; withExtra: root.extra; big: true }
        }
    }

    Component {
        id: miniL
        ColumnLayout {
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Cover { size: 52; radius: Theme.radiusSmall + 2 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText { Layout.fillWidth: true; text: Media.title || I18n.tr("Ничего не играет"); font.bold: true; elide: Text.ElideRight }
                    // в мини-виде строка песни встаёт на место исполнителя
                    LyricsView { visible: root.lyricsMode !== "off"; Layout.fillWidth: true; rows: 1; small: true }
                    StyledText {
                        visible: root.lyricsMode === "off"
                        Layout.fillWidth: true
                        text: Media.artist
                        color: Media.accent
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }
                Strip { visible: root.spectrum === "strip"; bandsCount: 6; barHeight: 22 }
                Controls { visible: root.controls; withExtra: false; compact: true }
            }
            Progress { visible: root.progress; Layout.fillWidth: true; slim: true }
        }
    }

    Component {
        id: vinylL
        RowLayout {
            spacing: 22
            Vinyl { Layout.alignment: Qt.AlignTop; size: 190 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                TrackInfo { Layout.fillWidth: true }
                LyricsView { visible: root.lyricsMode !== "off"; Layout.fillWidth: true; Layout.topMargin: 6; rows: root.lyricsMode === "lines" ? 3 : 1 }
                Strip { visible: root.spectrum === "strip"; Layout.topMargin: 6; Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
                Progress { visible: root.progress; Layout.fillWidth: true }
                Controls { visible: root.controls; withExtra: root.extra }
            }
        }
    }

    Component {
        id: lyricsL
        ColumnLayout {
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Cover { size: 48; radius: Theme.radiusSmall + 2 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText { Layout.fillWidth: true; text: Media.title || I18n.tr("Ничего не играет"); font.bold: true; elide: Text.ElideRight }
                    StyledText { Layout.fillWidth: true; text: Media.artist; color: Media.accent; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                }
                Strip { visible: root.spectrum === "strip"; bandsCount: 8; barHeight: 24 }
                Controls { visible: root.controls; withExtra: false; compact: true }
            }
            LyricsView { Layout.fillWidth: true; rows: 5; big: true }
            Progress { visible: root.progress; Layout.fillWidth: true; slim: true }
        }
    }

    // ================= детали =================

    component Cover: ClippingRectangle {
        id: cov
        property int size: 104
        implicitWidth: size
        implicitHeight: size
        radius: Theme.radius
        color: Theme.surface0
        Image {
            id: img
            anchors.fill: parent
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(cov.size * 2, cov.size * 2)
            asynchronous: true
            visible: status === Image.Ready
        }
        MIcon { anchors.centerIn: parent; visible: !img.visible; icon: "music_note"; size: cov.size * 0.38; color: Media.accent }
    }

    component TrackInfo: ColumnLayout {
        id: ti
        property bool centered: false
        spacing: 2
        StyledText {
            Layout.fillWidth: true
            text: Media.title || I18n.tr("Ничего не играет")
            font.bold: true
            font.pixelSize: Theme.fontSizeLarge
            horizontalAlignment: ti.centered ? Text.AlignHCenter : Text.AlignLeft
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: Media.artist
            color: Media.accent
            horizontalAlignment: ti.centered ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight
        }
    }

    // спектр полоской; на паузе гаснет, но место держит — виджет не прыгает
    component Strip: Item {
        id: st
        property int bandsCount: 0     // 0 — сколько влезет по ширине
        property int barHeight: 22
        property color tint: Media.accent
        implicitWidth: vis.implicitWidth
        implicitHeight: barHeight
        Visualizer {
            id: vis
            anchors.centerIn: parent
            bands: st.bandsCount > 0 ? st.bandsCount : Math.max(4, Math.floor((st.width + spacing) / (barWidth + spacing)))
            barWidth: 4
            spacing: 3
            maxHeight: st.barHeight
            minHeight: 2
            mirrored: true
            fade: true
            color: st.tint
            opacity: Media.playing ? 1 : 0.3
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        }
    }

    component Progress: RowLayout {
        id: pr
        property bool slim: false
        readonly property var pl: Media.player
        readonly property real len: Number(pl?.length ?? 0)
        readonly property real pos: Number(pl?.position ?? 0)
        // браузеры (Firefox) часто не сообщают длительность — тогда без полосы, только прошедшее время
        readonly property bool known: len > 0 && len + 1 >= pos
        spacing: 10
        StyledText {
            visible: !pr.slim || !pr.known
            text: Media.fmt(pr.pos)
            color: Theme.subtext0
            font.pixelSize: Theme.fontSizeSmall
        }
        Slider {
            visible: pr.known
            Layout.fillWidth: true
            implicitHeight: pr.slim ? 10 : 22
            thickness: pr.slim ? 3 : 4
            color: Media.accent
            value: pr.known ? pr.pos / pr.len : 0
            onMoved: v => { if (pr.pl?.canSeek) pr.pl.position = v * pr.len; }
        }
        Item { visible: !pr.known; Layout.fillWidth: true }
        StyledText {
            visible: !pr.slim && pr.known
            text: Media.fmt(pr.len)
            color: Theme.subtext0
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    component Controls: Row {
        id: ct
        property bool withExtra: false
        property bool big: false
        property bool compact: false
        readonly property var pl: Media.player
        readonly property int sz: compact ? 30 : big ? 38 : 34
        spacing: compact ? 2 : big ? 14 : 6
        IconButton {
            visible: ct.withExtra && (ct.pl?.shuffleSupported ?? false)
            anchors.verticalCenter: parent.verticalCenter
            size: ct.sz - 4
            iconSize: 15
            icon: "shuffle"
            iconColor: ct.pl?.shuffle ? Media.accent : Theme.overlay1
            color: "transparent"
            onClicked: if (ct.pl) ct.pl.shuffle = !ct.pl.shuffle
        }
        IconButton { anchors.verticalCenter: parent.verticalCenter; size: ct.sz; iconSize: ct.sz / 2; icon: "skip_previous"; onClicked: ct.pl?.previous() }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: ct.big ? 50 : ct.sz + 4
            iconSize: ct.big ? 24 : ct.sz / 2 + 2
            icon: Media.playing ? "pause" : "play_arrow"
            active: true
            activeColor: Media.accent
            onClicked: ct.pl?.togglePlaying()
        }
        IconButton { anchors.verticalCenter: parent.verticalCenter; size: ct.sz; iconSize: ct.sz / 2; icon: "skip_next"; onClicked: ct.pl?.next() }
        IconButton {
            visible: ct.withExtra && (ct.pl?.loopSupported ?? false)
            anchors.verticalCenter: parent.verticalCenter
            size: ct.sz - 4
            iconSize: 15
            readonly property int st: ct.pl?.loopState ?? MprisLoopState.None
            icon: st === MprisLoopState.Track ? "repeat_one" : "repeat"
            iconColor: st !== MprisLoopState.None ? Media.accent : Theme.overlay1
            color: "transparent"
            onClicked: if (ct.pl) ct.pl.loopState = st === MprisLoopState.None ? MprisLoopState.Playlist
                : st === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
        }
    }

    // текст песни: звучащая строка по центру, соседние бледнее; список плавно едет
    component LyricsView: Item {
        id: lv
        property int rows: 3
        property bool centered: false
        property bool big: false
        property bool small: false
        readonly property int fs: big ? Theme.fontSizeLarge + 2 : small ? Theme.fontSizeSmall : Theme.fontSize
        readonly property int rowH: Math.round(fs * (big ? 1.9 : 1.6))
        readonly property int align: centered ? Text.AlignHCenter : Text.AlignLeft
        implicitHeight: rows * rowH
        clip: true

        ListView {
            id: lst
            anchors.fill: parent
            visible: Lyrics.has
            model: Lyrics.lines
            currentIndex: Math.max(0, Lyrics.index)
            interactive: false
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (height - lv.rowH) / 2
            preferredHighlightEnd: (height + lv.rowH) / 2
            highlightMoveDuration: Settings.appearance.animations ? Theme.anim * 1.5 : 0
            highlightMoveVelocity: -1
            delegate: StyledText {
                required property var modelData
                required property int index
                readonly property int d: Math.abs(index - Lyrics.index)
                width: lst.width
                height: lv.rowH
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: lv.align
                text: modelData[1] || "♪"
                elide: Text.ElideRight
                font.pixelSize: d === 0 && !lv.small ? lv.fs + 2 : lv.fs
                font.weight: d === 0 ? Font.Bold : Font.Medium
                color: d === 0 ? (lv.small ? Media.accent : Theme.text) : Theme.overlay1
                opacity: d === 0 ? 1 : d === 1 ? 0.75 : 0.4
                Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            }
        }
        StyledText {
            anchors.fill: parent
            visible: !Lyrics.has
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: lv.align
            text: !Media.active ? "♪" : Lyrics.loading ? I18n.tr("Ищу текст…") : I18n.tr("Текста для этой песни нет")
            color: Theme.overlay0
            font.pixelSize: lv.fs
            font.italic: true
            elide: Text.ElideRight
        }
    }

    // пластинка: обложка — «яблоко» в центре, диск крутится, пока играет; тонарм ложится на диск
    component Vinyl: Item {
        id: vy
        property int size: 190
        implicitWidth: size + 18
        implicitHeight: size
        Item {
            id: disc
            width: vy.size
            height: vy.size
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#111216"
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.12)
            }
            // бороздки
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: vy.size * (0.92 - index * 0.075)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, index % 2 ? 0.05 : 0.09)
                }
            }
            // блик
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                rotation: 35
                gradient: Gradient {
                    GradientStop { position: 0.30; color: "transparent" }
                    GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.07) }
                    GradientStop { position: 0.70; color: "transparent" }
                }
            }
            ClippingRectangle {
                anchors.centerIn: parent
                width: vy.size * 0.4
                height: width
                radius: width / 2
                color: Media.accent
                Image {
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(160, 160)
                    asynchronous: true
                }
            }
            Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: "#111216" }

            RotationAnimator on rotation {
                from: 0; to: 360
                duration: 1800 * 2   // ~33 об/мин было бы мельтешением — вдвое медленнее
                loops: Animation.Infinite
                running: Media.playing && Settings.appearance.animations
                // на паузе диск не прыгает в 0 — следующий оборот продолжается с текущего угла
                onRunningChanged: if (running) { from = disc.rotation; to = disc.rotation + 360; }
            }
        }
        // тонарм
        Item {
            x: vy.size - 6
            y: 4
            width: 16
            height: vy.size * 0.62
            transformOrigin: Item.Top
            rotation: Media.playing ? 24 : 4
            Behavior on rotation { NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 14; height: 14; radius: 7; color: Theme.surface1; border.width: 2; border.color: Theme.overlay0 }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 7; width: 4; height: parent.height - 18; radius: 2; color: Theme.overlay1 }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; width: 10; height: 16; radius: 3; color: Theme.subtext0 }
        }
    }
}
