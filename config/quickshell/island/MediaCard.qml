import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Большой плеер. Без музыки — приветствие и аптайм.
Card {
    id: card
    implicitWidth: 300

    readonly property var p: Media.player

    function greeting(): string {
        const h = new Date().getHours();
        if (h < 5) return I18n.tr("Доброй ночи");
        if (h < 12) return I18n.tr("Доброе утро");
        if (h < 18) return I18n.tr("Добрый день");
        return I18n.tr("Добрый вечер");
    }

    // --- приветствие ---
    ColumnLayout {
        anchors.fill: parent
        visible: !Media.active
        spacing: 6

        Item { Layout.fillHeight: true }
        MIcon {
            icon: "cove"
            color: Theme.accent
            size: 44
        }
        StyledText {
            Layout.fillWidth: true
            text: `${card.greeting()},\n${Settings.displayName}`
            font.pixelSize: 22
            font.bold: true
            wrapMode: Text.Wrap
        }
        StyledText {
            text: I18n.tr("Сейчас ничего не играет")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
        }
        Item { Layout.fillHeight: true }
    }

    // --- плеер ---
    // фон — размытая обложка (под содержимым карточки, по её скруглению)
    // лежит в области содержимого, но растянут на всю карточку (за отступы)
    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: -card.padding
        z: -1
        radius: card.radius
        color: "transparent"
        visible: Media.active && art.status === Image.Ready
        Image {
            anchors.fill: parent
            anchors.margins: -40
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(160, 160)
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.2 }
            opacity: 0.32
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.alpha(Theme.mantle, 0.2) }
                GradientStop { position: 1.0; color: Theme.alpha(Theme.mantle, 0.85) }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: Media.active
        spacing: 10

        RowLayout {
            spacing: 12
            ClippingRectangle {
                implicitWidth: 84
                implicitHeight: 84
                radius: Theme.radiusSmall + 2
                color: Theme.surface0
                Image {
                    id: art
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(168, 168)
                    visible: status === Image.Ready
                }
                MIcon {
                    anchors.centerIn: parent
                    visible: !art.visible
                    icon: "music_note"
                    color: Media.accent
                    size: 32
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: Media.title
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: Media.artist
                    color: Media.accent
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    // «Mozilla firefox» → «Firefox»
                    text: { const s = (card.p?.identity ?? "").replace(/^Mozilla\s+/i, ""); return s.charAt(0).toUpperCase() + s.slice(1); }
                    color: Theme.overlay0
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }
        }

        // текст песни: звучащая строка и следующая — на месте спектра
        ColumnLayout {
            Layout.fillWidth: true
            visible: Settings.island.lyrics && Lyrics.has
            spacing: 1
            StyledText {
                id: curLine
                Layout.fillWidth: true
                text: Lyrics.line || "♪"
                color: Theme.text
                font.bold: true
                elide: Text.ElideRight
                Behavior on text { SequentialAnimation {
                    NumberAnimation { target: curLine; property: "opacity"; to: 0.2; duration: 90 }
                    PropertyAction {}
                    NumberAnimation { target: curLine; property: "opacity"; to: 1; duration: Theme.anim }
                } }
            }
            StyledText {
                Layout.fillWidth: true
                text: Lyrics.nextLine
                color: Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        // спектр: место держим всегда, на паузе гаснет — карточка не прыгает
        Visualizer {
            Layout.alignment: Qt.AlignHCenter
            visible: Settings.island.visualizer && !(Settings.island.lyrics && Lyrics.has)
            bands: 28
            barWidth: 4
            spacing: 4
            maxHeight: 26
            minHeight: 2
            mirrored: true
            fade: true
            opacity: Media.playing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            StyledText {
                text: Media.fmt(card.p?.position ?? 0)
                color: Theme.subtext0
                font.pixelSize: Theme.fontSizeSmall
            }
            Slider {
                Layout.fillWidth: true
                thickness: 4
                color: Media.accent
                value: card.p && card.p.length > 0 ? card.p.position / card.p.length : 0
                onMoved: v => { if (card.p?.canSeek) card.p.position = v * card.p.length; }
            }
            StyledText {
                text: Media.fmt(card.p?.length ?? 0)
                color: Theme.subtext0
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            IconButton { size: 36; iconSize: 18; icon: "skip_previous"; onClicked: card.p?.previous() }
            IconButton {
                size: 46
                iconSize: 22
                icon: Media.playing ? "pause" : "play_arrow"
                active: true
                activeColor: Media.accent
                onClicked: card.p?.togglePlaying()
            }
            IconButton { size: 36; iconSize: 18; icon: "skip_next"; onClicked: card.p?.next() }
        }
    }
}
