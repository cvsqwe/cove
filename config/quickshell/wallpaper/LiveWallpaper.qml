import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.services

// Живые обои: видео (mp4/webm/mkv/mov из папки обоев) поверх постера, который рисует awww.
// В игровом режиме и когда на экране полноэкранное окно — пауза; под окнами размывается,
// как и обычные обои (Settings.wallpaper.blurWindows).
Variants {
    model: Store.isVideo(Store.wallpaper) ? Quickshell.screens : []

    PanelWindow {
        id: win
        required property ShellScreen modelData
        screen: modelData

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "qs-live-wallpaper"
        color: "transparent"
        // клики проходят на рабочий стол
        mask: Region {}

        // полноэкранное окно на этом мониторе закрывает обои целиком — не тратим на них GPU
        readonly property bool paused: GameMode.active || (Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)

        Video {
            id: video
            anchors.fill: parent
            source: "file://" + Store.wallpaper
            fillMode: VideoOutput.PreserveAspectCrop
            loops: MediaPlayer.Infinite
            muted: !Settings.wallpaper.liveSound
            autoPlay: !win.paused
            opacity: playbackState === MediaPlayer.PlayingState || playbackState === MediaPlayer.PausedState ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600 } }
            onErrorOccurred: (e, s) => console.warn("live wallpaper:", s)

            layer.enabled: Wallpapers.blurNow
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: 48
            }
        }

        onPausedChanged: paused ? video.pause() : video.play()
    }
}
